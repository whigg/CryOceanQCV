function daily_GOP_sla(day_date,data_type,path1,path2)
% read a daily file as generated by the function 'read_cryo2Data.m',
% compute statistics and save them in a structure.
%
% USAGE : daily_stats(day_date,data_type)
%
% INPUT :    day_date : date of the day for which we want to calculate
%                       statistics in format 'yyyymmdd'
%            data_type : string denoting the name of the product. Possible
%                        values are 'SIR_FDM_L2', 'SIR_IOP_L2', SIR_GOP_L2'
%            path1 : path to the matlab files containing data to process
%            path2 : path to latency data
%            path3 : path to folder where statistics are saved
%
% OUTPUT : this function has no outputs
%
% author : Francisco Mir Calafat (francisco.calafat@noc.ac.uk)
%
%% load data
data = load([path1 data_type '_' day_date '.mat']);
data = data.(char(fieldnames(data)));
load('/noc/users/fmc1q07/QCV_Cryo2/code/DTU10MSS.mat') % dtu10 MSS for the 20-Hz data


%% read data
tutc = data.utc_time;
dt = diff(tutc);
kt = [true dt ~= 0];

%DATES
dates = datenum(2000,1,1)+data.utc_time./(24*3600); %UTC time
tStart = datestr(dates(1),'dd mm yyyy HH:MM:SS.FFF'); %start date
tStop = datestr(dates(end),'dd mm yyyy HH:MM:SS.FFF'); % stop date

% COORDINATES and SURFACE TYPE
lon = data.lon(kt);
lat = data.lat(kt);
hi_lon = data.hi_lon(:,kt);
hi_lat = data.hi_lat(:,kt);
surface_type = data.flag_surface_type(kt);
flag_block = data.flag_mcd_block_degraded(:,kt); %records should not be used if 1

% SWH
swh = data.swh(kt);
flag_swh_av = data.flag_swh_av(:,kt);
hi_swh = data.hi_swh(:,kt);



% RANGE, CORRECTED RANGE, SSH and SLA
h = data.h(kt);
range = data.range(kt);
flag_range_av = data.flag_range_av(:,kt);
hi_h = data.hi_h(:,kt);
hi_range = data.hi_range(:,kt);
corr_iono_gim = data.corr_iono_gim(kt);
corr_dry_trop = data.corr_dry_trop(kt);
corr_wet_trop_mod = data.corr_wet_trop_mod(kt);
corr_atm = data.corr_dac(kt);
corr_IB = data.corr_inv_baro(kt);
corr_atm(isnan(corr_atm)) = corr_IB(isnan(corr_atm));
corr_ssb = data.corr_ssb(kt);
h_mss2 = data.h_mss2(kt); %DTU10 MSS
h_tot_geocen_ocn_tide_sol1 = data.h_tot_geocen_ocn_tide_sol1(kt);
h_tide_solid = data.h_tide_solid(kt);
h_tide_geocen_pole = data.h_tide_geocen_pole(kt);

range_correc = range + corr_wet_trop_mod + corr_dry_trop + ...
    corr_iono_gim + corr_ssb; % corrected range

ssh = h - range_correc - h_tide_solid - h_tot_geocen_ocn_tide_sol1 - ...
    h_tide_geocen_pole - corr_atm; % SSH

hi_ssh = hi_h - hi_range; % uncorrected!

sla = ssh - h_mss2; % SLA

% interpolate MSS for 20-Hz data and compute SLA
hi_sla = hi_ssh-read_mssh(hi_lon,hi_lat,'dtu10');
dates = dates(kt);

%% compute statistics and build structure

dataStat.date = cellstr(datestr(datenum(day_date,'yyyymmdd'),'dd/mm/yyyy'));
dataStat.tutc = dates; % matlab timestamp
dataStat.tStart = cellstr(tStart);
dataStat.tStop = cellstr(tStop);
dataStat.ssha = sla;
dataStat.swh = swh;
dataStat.lon = lon;
dataStat.lat = lat;
dataStat.surface_type = surface_type;
dataStat.flag_block = flag_block;
dataStat.flag_range = flag_range_av;
dataStat.flag_swh = flag_swh_av;
dataStat.nrec = length(lon);

% CALCULATIONS
k0 = hi_range == 0; % The last 20-Hz record in each file may contain zeros
hi_sla(k0) = NaN;
hi_swh(k0) = NaN;
params = {sla,swh};
fields = {'ssha','swh'};
hi_params = {hi_sla,hi_swh};

% ----------------------------editing criteria-----------------------------
% 20-Hz blocks with less than 10 measurements will be rejected
thrm = {[-10 10],[0 15]}; % min and max thresholds for measurements
thrstd = [0.15,1.0];
thrIB = [-2.0,2.0]; 
nan1 = cell(1,1);
nanNOC = cell(1,1);
for i=1:2
    x = params{i};
    hi_x = hi_params{i};
    if i < 4
        %hi_flg = find(flg == 1); % IOP 1 = bad measurement (flag seems wrong hence we don't use it for IOP)
        nflg = sum(~isnan(hi_x),1); % number of measurements in each 20Hz block
        x(nflg < 10) = NaN;
        hi_x(:,nflg < 10) = NaN;
        params{i} = x;
        hi_params{i} = hi_x;
    end
    x = params{i};
    nan1{i} = (~isnan(x) & (surface_type == 0 | surface_type == 1));
    
    % NOC criteria
    if i < 5
        x = params{i};
        hi_x = hi_params{i};
        x = x(nan1{i});
        if i==1
            hi_x = hi_x(:,nan1{i});
            nanNOC{i} = x >= thrm{i}(1) & x <= thrm{i}(2) & corr_IB(nan1{i}) >= thrIB(1) & ...
                corr_IB(nan1{i}) <= thrIB(2) & nanstd(hi_x) <= thrstd(i);
        else
            hi_x = hi_x(:,nan1{i});
            nanNOC{i} = x >= thrm{i}(1) & x <= thrm{i}(2) & ...
                nanstd(hi_x) <= thrstd(i);
        end
    end
end
% -----------------------------------------------------end editing criteria

for i=1:length(params)
    x = params{i};
    nan_x = nan1{i};
    x = x(nan_x);

    dataStat.(['validFlag_' fields{i}]) = nan_x;
    dataStat.(['nrec_' fields{i}]) = length(x);
    perctile = prctile(x,[5 25 75 95]);
    dataStat.(['mean_' fields{i}]) = mean(x);
    dataStat.(['median_' fields{i}]) = median(x);
    dataStat.(['std_' fields{i}]) = std(x);
    dataStat.(['p5_' fields{i}]) = perctile(1);
    dataStat.(['p25_' fields{i}]) = perctile(2);
    dataStat.(['p75_' fields{i}]) = perctile(3);
    dataStat.(['p95_' fields{i}]) = perctile(4);
    if(i < 5)
        if i ~=4
            hi_x = hi_params{i};
            hi_x = hi_x(:,nan_x);
            hi_lo = hi_lon(:,nan_x);
            hi_la = hi_lat(:,nan_x);
            dx = abs(diff(hi_lo(:)));
            dy = abs(diff(hi_la(:)));
            diffxy = diff(hi_x(:));
            diffxy(dx > 0.05 | dy > 0.05) = [];
            dataStat.(['noise_' fields{i}]) = nanstd(hi_x);
            dataStat.(['noiseavg_' fields{i}]) = nanmean(nanstd(hi_x));
            dataStat.(['noiseStd_' fields{i}]) = nanstd(nanstd(hi_x));
            dataStat.(['noiseDiff_' fields{i}]) = nanstd(diffxy)/sqrt(2);
        end
        
        
        % precise quantities based on scientific thresholds
        nan_x2 =  nanNOC{i};
        x = x(nan_x2);
        dataStat.(['validNOC_' fields{i}]) = nan_x2;
        perctile = prctile(x,[5 25 75 95]);
        dataStat.(['nrecNOC_' fields{i}]) = length(x);
        dataStat.(['meanNOC_' fields{i}]) = mean(x);
        dataStat.(['medianNOC_' fields{i}]) = median(x);
        dataStat.(['stdNOC_' fields{i}]) = std(x);
        dataStat.(['p5NOC_' fields{i}]) = perctile(1);
        dataStat.(['p25NOC_' fields{i}]) = perctile(2);
        dataStat.(['p75NOC_' fields{i}]) = perctile(3);
        dataStat.(['p95NOC_' fields{i}]) = perctile(4);
        if i ~= 4
            hi_x = hi_x(:,nan_x2);
            dataStat.(['noiseNOC_' fields{i}]) = nanstd(hi_x);
            dataStat.(['noiseavgNOC_' fields{i}]) = nanmean(nanstd(hi_x));
            dataStat.(['noiseStdNOC_' fields{i}]) = nanstd(nanstd(hi_x));
            dataStat.(['noiseDiffNOC_' fields{i}]) = NaN;
        end
        
    end
end

save([path2 'GOP_sla_' data_type '_' day_date '.mat'],'-struct','dataStat')
