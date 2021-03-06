function daily_stats_v6_FOR_CATCHUP(day_date,data_type,path1,path2,path3,mss,gshhs,ground)
% read a daily file as generated by the function 'read_cryo2Data.m',
% compute statistics and savem them in a structure.
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
%            mss   : DTU10 Mean Sea sSurfacee
%            gshhs : coast lines (seems to be intermediate product)
%            ground: groundtracks
% OUTPUT : this function has no outputs
%
% author : Francisco Mir Calafat (francisco.calafat@noc.ac.uk)
%
%% load data
path4 = '/noc/users/cryo/QCV_Cryo2/code/';
% UPDATE HERE JAN 2017
% path_val = '/scratch/general/cryosat/validation_data/';
path_val = '/noc/mpoc/cryo/cryosat/validation_data/';

% load data for the type (data_type) and day of interest (day_date)
data = load([path1 day_date(1:4) '/' day_date(5:6) '/' data_type '_' day_date '.mat']);
data = data.(char(fieldnames(data)));
DTU10MSS = mss; %#ok
A = ground; % format appears to be (by row) year, month, day, hr?, min? sec?
% two second range, orbut ID (in some form), and lon, lat

%% compute percentage of ocean data per day and orbit
% This is computed from the ground tracks.
% will need updating if new ground mask employed
if datenum(day_date,'yyyymmdd') >= datenum('20170322','yyyymmdd')
    mask_v = '9';
    warning('not sure on EXACT date of change of mode mask need to fill in')
elseif datenum(day_date,'yyyymmdd') >= datenum('20160307','yyyymmdd')
    mask_v = '8';
elseif datenum(day_date,'yyyymmdd') >= datenum('20151214','yyyymmdd')
    mask_v = '7';
elseif datenum(day_date,'yyyymmdd') >= datenum('20141006','yyyymmdd')
    mask_v = '6';
elseif datenum(day_date,'yyyymmdd') >= datenum('20140701','yyyymmdd')
    warning('not sure on EXACT day in July 2014')
    mask_v = '5';
elseif datenum(day_date,'yyyymmdd') >= datenum('20121001','yyyymmdd')
    warning('not sure on EXACT day in Oct 2012')
    mask_v = '4';
else
    error('what geographical mode mask version?')
    mask_v = '2';
end
load([path4 'mode_mask/seasMask_noLRM_3_' mask_v '.mat']); % mode mask
load([path4 'mode_mask/seasMask_polar.mat']); % arctic mask
load([path4 'mode_mask/Mask_SARin_3_' mask_v '.mat']);
[Y0,M0,D0] = datevec(datenum(day_date,'yyyymmdd'));
KGT = (A(1,:) == Y0 & A(2,:) == M0 & A(3,:) == D0); % find data for day of interest
xg = A(8,KGT);
yg = A(9,KGT);
xg(xg > 180) = xg(xg > 180)-360;

% choose seasonal mode mask and compute percentage of data over LRM areas for FDM
seasMonth = day_date(5:6);
seasDay = day_date(end-1:end);
seas = 2*(str2num(seasMonth)-1); %#ok
if(str2double(seasDay) < 15)
    seas = seas+1;
else
    seas = seas+2;
end

no_LRM_mask = seasMask.(['seas_' sprintf('%1.2d',seas)]);
SARin_mask = SARinMask.(['seas_' sprintf('%1.2d',seas)]);
polar = polar{seas}; %#ok
dataStat.polarMask = polar;
% functions to see if masked by ESA ground masks
outLRM = ~isLRM(data.lon,data.lat,no_LRM_mask);
outSARin = isLRM(data.lon,data.lat,SARin_mask);
kLRM = isLRM(xg,yg,no_LRM_mask);
noPolarg = isLRM(xg,yg,polar);
kSARin = ~isLRM(xg,yg,SARin_mask); %points inside SARin areas
kocean = ~island(xg,yg,gshhs,1);
perc_outSARin = sum(~kSARin)/length(kSARin)*100;
perc_LRMDay = sum(kLRM)/length(kLRM)*100; % percentage of LRM data over total in a day
if strcmp(data_type,'SIR_FDM_L2')
    koLRM = and(kLRM,kocean);
    perc_ocean = sum(koLRM)/length(xg)*100; % percentage LRM data over ocean for day
    perc_ocean_noPolar = sum(koLRM & noPolarg)/length(xg)*100;
else
    kSARLRM = and(~kSARin,kocean);
    perc_ocean = sum(kSARLRM)/length(xg)*100; % percentage ocean for day
    perc_ocean_noPolar = sum(kSARLRM & noPolarg)/length(xg)*100;
end

% percentage of ocean data per orbit (may overlap neighbouring days)
orbitU = unique(A(7,KGT)); % unique orbits
Korb = find(A(7,:) >= orbitU(1) & A(7,:) <= orbitU(end)); % find all cases with orbit numbers from given day (or days either side)
% replace exiting xg and yg (lon/lat)y
xg = A(8,Korb);
yg = A(9,Korb);
xg(xg > 180) = xg(xg > 180)-360;
kLRM = isLRM(xg,yg,no_LRM_mask);
kSARin = ~isLRM(xg,yg,SARin_mask); %points inside SARin areas
kocean = ~island(xg,yg,gshhs,1);
if strcmp(data_type,'SIR_FDM_L2')
    kocean = and(kLRM,kocean);
else
    kocean = and(~kSARin,kocean);
end
perc = zeros(1,length(orbitU));
perc_LRMOrb = zeros(1,length(orbitU)); % percentage of LRM data over total per orbit
perc_outSARinOrb = zeros(1,length(orbitU));
for i=1:length(orbitU) % for each unique orbit find valid %
    ko = A(7,Korb) == orbitU(i);
    perc(i) = sum(and(kocean,ko))/sum(ko)*100;
    perc_LRMOrb(i) = sum(and(kLRM,ko))/sum(ko)*100;
    perc_outSARinOrb(i) = sum(and(~kSARin,ko))/sum(ko)*100;
end
perc_orbOcean = containers.Map(orbitU,perc);
perc_LRMOrb = containers.Map(orbitU,perc_LRMOrb);
perc_outSARinOrb = containers.Map(orbitU,perc_outSARinOrb);


%% read data
tutc = data.utc_time;
[~,ix] = unique(tutc,'stable'); % there are often repeated values
kt = false(size(tutc));
kt(ix) = true;
if strcmp(data_type,'SIR_FDM_L2')
    kt = and(kt,~outLRM); % we reject points for FDM in non-FDM regions
else
    kt = and(kt,outSARin);
end
%DATES
dates = datenum(2000,1,1)+data.utc_time./(24*3600); %UTC time
tStart = datestr(dates(1),'dd mm yyyy HH:MM:SS.FFF'); %start date
tStop = datestr(dates(end),'dd mm yyyy HH:MM:SS.FFF'); % stop date
hi_utc = data.hi_utctime(:,kt);

% COORDINATES and SURFACE TYPE
lon = data.lon(kt);
lat = data.lat(kt);
hi_lon = data.hi_lon(:,kt); % high rate lon
hi_lat = data.hi_lat(:,kt);
surface_type = data.flag_surface_type(kt);
flag_block = data.flag_mcd_block_degraded(:,kt); %records should not be used if 1

% SWH
swh = data.swh(kt);
if strcmp(data_type,'SIR_FDM_L2')
    flag_swh_av = data.flag_swh_sq_av(:,kt);
    hi_swh_sq = data.hi_swh_sq(:,kt);
    hi_swh_sq(hi_swh_sq < 0) = NaN;
    hi_swh = sqrt(hi_swh_sq);
else
    flag_swh_av = data.flag_swh_av(:,kt);
    hi_swh = data.hi_swh(:,kt);
end

% DEPTH
depth = data.h_dem(kt);

% WIND SPEED
wsp = data.wsp(kt);

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

% save max and min and valid number for corrections
dataStat.corrections.ionoMax = max(corr_iono_gim(~isnan(corr_iono_gim)));
dataStat.corrections.ionoMin = min(corr_iono_gim(~isnan(corr_iono_gim)));
dataStat.corrections.ionoNumValid = sum(~isnan(corr_iono_gim));
dataStat.corrections.dryMax = max(corr_dry_trop(~isnan(corr_dry_trop)));
dataStat.corrections.dryMin = min(corr_dry_trop(~isnan(corr_dry_trop)));
dataStat.corrections.dryNumValid = sum(~isnan(corr_dry_trop));
dataStat.corrections.wetMax = max(corr_wet_trop_mod(~isnan(corr_wet_trop_mod)));
dataStat.corrections.wetMin = min(corr_wet_trop_mod(~isnan(corr_wet_trop_mod)));
dataStat.corrections.wetNumValid = sum(~isnan(corr_wet_trop_mod));
dataStat.corrections.atmMax = max(corr_atm(~isnan(corr_atm)));
dataStat.corrections.atmMin = min(corr_atm(~isnan(corr_atm)));
dataStat.corrections.atmNumValid = sum(~isnan(corr_atm));
dataStat.corrections.ssbMax = max(corr_ssb(~isnan(corr_ssb)));
dataStat.corrections.ssbMin = min(corr_ssb(~isnan(corr_ssb)));
dataStat.corrections.ssbNumValid = sum(~isnan(corr_ssb));

% If all values in a correction are missing we set them to zero
if sum(~isnan(corr_iono_gim)) == 0
    corr_iono_gim(:) = 0;
end
if sum(~isnan(corr_dry_trop)) == 0
    corr_dry_trop(:) = 0;
end
if sum(~isnan(corr_wet_trop_mod)) == 0
    corr_wet_trop_mod(:) = 0;
end
if sum(~isnan(corr_atm)) == 0
    corr_atm(:) = 0;
end
if sum(~isnan(corr_ssb)) == 0
    corr_ssb(:) = 0;
end


if strcmp(data_type,'SIR_FDM_L2')
    h_mss2 = data.h_mss1(kt); % there is only one mss
else
    h_mss2 = data.h_mss2(kt); %DTU10 MSS
end
h_tot_geocen_ocn_tide_sol1 = data.h_tot_geocen_ocn_tide_sol1(kt);
h_tide_solid = data.h_tide_solid(kt);
h_tide_geocen_pole = data.h_tide_geocen_pole(kt);

range_correc = range + corr_wet_trop_mod + corr_dry_trop + ...
    corr_iono_gim + corr_ssb; % corrected range

ssh = h - range_correc - h_tide_solid - h_tot_geocen_ocn_tide_sol1 - ...
    h_tide_geocen_pole - corr_atm; % SSH

% --------------- interpolate corrections for 20Hz data -------------------
%NOTE : time increments are sometimes negative! when negative increments
%are found then the hi_sla is set to NaNs
hi_mssh = read_mssh(hi_lon,hi_lat,'dtu10') - dh_ellips(hi_lat);
if(sum(diff(tutc(kt)) < 0) == 0)
    hi_wet = interp1(tutc(kt),corr_wet_trop_mod,hi_utc);
    hi_dry = interp1(tutc(kt),corr_dry_trop,hi_utc);
    hi_ion = interp1(tutc(kt),corr_iono_gim,hi_utc);
    hi_ssb = interp1(tutc(kt),corr_ssb,hi_utc);
    
    hi_range_correc = hi_range + hi_wet + hi_dry + hi_ion + hi_ssb;
    clear hi_wet hi_dry hi_ion hi_ssb
    
    hi_solid = interp1(tutc(kt),h_tide_solid,hi_utc);
    hi_tide = interp1(tutc(kt),h_tot_geocen_ocn_tide_sol1,hi_utc);
    hi_pole = interp1(tutc(kt),h_tide_geocen_pole,hi_utc);
    hi_atm = interp1(tutc(kt),corr_atm,hi_utc);
    
    hi_ssh = hi_h - hi_range_correc - hi_solid - hi_tide - hi_pole - hi_atm;
    hi_ssha = hi_ssh - hi_mssh;
else
    disp('negative time increments')
    hi_ssha = NaN(size(hi_lon));
end

clear hi_range_correc hi_solid hi_tide hi_pole hi_atm
% --------------- end interpolating ---------------------------------------

hi_ssh = hi_h - hi_range; % uncorrected!

sla = ssh - h_mss2; % SLA


% ------------- save data in different file for validation ------------
if strcmp(data_type,'SIR_GOP_L2')
    %ssh = h - range_correc - h_tide_solid;
    dataStat.mss = h_mss2;
    dataStat.wet = corr_wet_trop_mod;
    dataStat.dry = corr_dry_trop;
    dataStat.iono = corr_iono_gim;
    dataStat.ssb = corr_ssb;
    %dataStat.solid = h_tide_solid;
    %dataStat.totOcn_tide = h_tot_geocen_ocn_tide_sol1;
    %dataStat.poleTide = h_tide_geocen_pole;
    dataStat.atm = corr_atm;
    %dataStat.range = range;
    %dataStat.alt = h;
end
% ---------------------------------------------------------------------



% interpolate MSS for 20-Hz data and compute SLA
hi_sla = hi_ssh - hi_mssh;

% SIGMA0
sigma0 = data.sigma0(kt);
flag_sigma0_av = data.flag_sigma0_av(:,kt);
hi_sigma0 = data.hi_sigma0(:,kt);

% MISPOINTING
if strcmp(data_type,'SIR_FDM_L2')
    mispoint = (data.off_nad_ang_platform(kt)).^2;
else
    mispoint = data.off_nad_ang_sq_wvform(kt);
end

%ORBITS
KGT = find(KGT);
gr0 = 1;
grf = 1;
if A(7,KGT(1)-1) == A(7,KGT(1))
    gr0 = 0;
end
if A(7,KGT(end)+1) == A(7,KGT(end))
    grf = 0;
end
komax = max(Korb);
A = A(:,[Korb komax+1]);
to = datenum(A(1,:),A(2,:),A(3,:),A(4,:),A(5,:),A(6,:));
orbits = zeros(1,length(data.lon));
ascendingFlag = zeros(1,length(data.lon));
for i=1:length(data.lon)
    dt = abs(dates(i)-to);
    kdt = find(dt == min(dt),1);
    orbits(i) = A(7,kdt);
    if A(9,kdt+1)-A(9,kdt) > 0
        ascendingFlag(i) = 1;
    else
        ascendingFlag(i) = 0;
    end
end
orbits = orbits(kt);
dates = dates(kt);
ascendingFlag = ascendingFlag(kt);


%% compute statistics and build structure
% read latecy data
% % % % % % % % % % % % % % laten = load([path2 data_type(5:8) 'latency.txt']);
% % % % % % % % % % % % % % laten(:,1) = fix(laten(:,1)/(24*3600))+datenum(1970,1,1);
% % % % % % % % % % % % % % klaten = ismember(laten(:,1),datenum(day_date,'yyyymmdd'));
% % % % % % % % % % % % % % laten = laten(klaten,:)';
laten = orbits + NaN;

dataStat.modeSeas = seas;
dataStat.date = cellstr(datestr(datenum(day_date,'yyyymmdd'),'dd/mm/yyyy'));
dataStat.tutc = dates; % matlab timestamp
dataStat.hi_utc = hi_utc;
dataStat.laten = laten;
dataStat.tStart = cellstr(tStart);
dataStat.tStop = cellstr(tStop);
dataStat.orbits = orbits;
dataStat.ascendingFlag = ascendingFlag;
dataStat.orbitFirstFull = gr0;
dataStat.orbitLastFull = grf;
% if strcmp(data_type,'SIR_GOP_L2')
%     dataStat.ssh = ssh;
% end
dataStat.ssha = sla;
dataStat.swh = swh;
dataStat.wsp = wsp;
dataStat.sigma0 = sigma0;
dataStat.misp = mispoint;
dataStat.lon = lon;
dataStat.lat = lat;
dataStat.hi_lon = hi_lon;
dataStat.hi_lat = hi_lat;
dataStat.hi_ssha = hi_ssha;
dataStat.depth = depth;
dataStat.perc_LRMDay = perc_LRMDay; %from groundtracks to calculate theoretical max
dataStat.perc_outSARin = perc_outSARin;
dataStat.perc_LRMOrb = perc_LRMOrb;
dataStat.perc_outSARinOrb = perc_outSARinOrb;
dataStat.surface_type = surface_type;
dataStat.flag_block = flag_block;
dataStat.flag_range = flag_range_av;
dataStat.flag_swh = flag_swh_av;
dataStat.flag_sigma0 = flag_sigma0_av;
dataStat.nrec = length(lon);
dataStat.perc_ocean = perc_ocean;
dataStat.perc_ocean_noPolar = perc_ocean_noPolar;
dataStat.perc_orbOcean = perc_orbOcean;
dataStat.nrec_ocean = sum(surface_type == 0 | surface_type == 1);

% CALCULATIONS
k0 = hi_range == 0; % The last 20-Hz record in each file may contain zeros
hi_sla(k0) = NaN;
hi_swh(k0) = NaN;
hi_sigma0(k0) = NaN;

params = {sla,swh,sigma0,wsp,mispoint};
fields = {'ssha','swh','sigma0','wsp','misp'};
flags = {flag_range_av,flag_swh_av,flag_sigma0_av,zeros(size(flag_range_av)),...
    zeros(size(flag_range_av))};
hi_params = {hi_sla,hi_swh,hi_sigma0,[],[]};

% ----------------------------editing criteria-----------------------------
% 20-Hz blocks with less than 10 measurements will be rejected
noPolar = isLRM(lon,lat,polar); % points outside polar regions
dataStat.noPolar = noPolar;
if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
    inLRM = isLRM(lon,lat,no_LRM_mask); % points in LRM regions
    inLRM20Hz = isLRM(hi_lon,hi_lat,no_LRM_mask); % points in LRM regions
    dataStat.inLRM = inLRM;
    inLRM20Hz = reshape(inLRM20Hz,size(hi_lon));
    dataStat.inLRM20Hz = inLRM20Hz;
end
thrm = {[-3 3],[0 15],[7 30],[0 30]}; % min and max thresholds for measurements
thrstd = [0.20,1.0,0.23];
thrIB = [-2.0,2.0];
thrwet = [-0.5,-0.001];
thrdry = [-2.5,-1.9];
thriono = [-0.4,0.04];
thrssb = [-0.5,0.0];
nan1 = cell(length(params),1);
nanNOC = cell(4,1);
for i=1:5
    x = params{i};
    hi_x = hi_params{i};
    flg = flags{i};
    if i < 4
        if strcmp(data_type,'SIR_FDM_L2')
            hi_x(flg(1:20,:) == 0) = NaN; % 0 = unused measurement
        end
        %hi_flg = find(flg == 1); % IOP 1 = bad measurement (flag seems wrong hence we don't use it for IOP)
        nflg = sum(~isnan(hi_x),1); % number of measurements in each 20Hz block
        x(nflg < 10) = NaN;
        hi_x(:,nflg < 10) = NaN;
        params{i} = x;
        hi_params{i} = hi_x;
    end
    x = params{i};
    if strcmp(data_type,'SIR_FDM_L2')
        nan1{i} = (~isnan(x) & flg(end,:) == 0 & (surface_type == 0 | ...
            surface_type == 1));
    else
        nan1{i} = (~isnan(x) & (surface_type == 0 | surface_type == 1));
    end
    
    % NOC criteria
    % ---------------------- find biases in orbits ------------------------
    if i == 1
        x = params{i};
        gu = unique(orbits);
        xo = zeros(1,length(gu));
        kbias = false(1,length(orbits));
        for j=1:length(gu)
            kg = orbits == gu(j) & nan1{i};
            xo(j) = sum(abs(x(kg)) > 0.90);
            if xo(j) > 100
                kx = abs(x) >= 0.0; % the whole orbit is rejected
                kx = and(kx,kg);
                kbias(kx) = true;
            end
        end
        dataStat.(['orbitBias_' fields{i}]) = xo; % save bias only for ssha
    end
    % ---------------------------------------- end finding biases in orbits
    if i < 5
        x = params{i};
        hi_x = hi_params{i};
        if i == 1
            hi_x2 = hi_params{3};
            editSLA = x >= thrm{i}(1) & x <= thrm{i}(2);
            editSLAstd = nanstd(hi_x) <= thrstd(i);
            editIB = corr_IB >= thrIB(1) & corr_IB <= thrIB(2);
            editBiasedOrbit = ~kbias;
            editWet = corr_wet_trop_mod >= thrwet(1) & corr_wet_trop_mod <= thrwet(2);
            editDry = corr_dry_trop >= thrdry(1) & corr_dry_trop <= thrdry(2);
            editIono = corr_iono_gim >= thriono(1) & corr_iono_gim <= thriono(2);
            editSsb = corr_ssb >= thrssb(1) & corr_ssb <= thrssb(2);
            editSigma0 = params{3} >= thrm{3}(1) & params{3} <= thrm{3}(2);
            editSigma0std = nanstd(hi_x2) <= thrstd(3);
            nanNOC{i} = editSLA & editIB & editSLAstd & editWet & editDry ...
                & editIono & editSsb & editSigma0 & editSigma0std ...
                & editBiasedOrbit;
        elseif i ~= 4
            if i == 2
                editSWH = x >= thrm{i}(1) & x <= thrm{i}(2);
                editSWHstd = nanstd(hi_x) <= thrstd(i);
            end
            nanNOC{i} = x >= thrm{i}(1) & x <= thrm{i}(2) & ...
                nanstd(hi_x) <= thrstd(i);
        else
            editWsp = x >= thrm{i}(1) & x <= thrm{i}(2);
            nanNOC{i} = editWsp;
        end
    end
end

% save percentage of edited data
n1 = sum(nan1{1} & noPolar);
n2 = sum(nan1{2} & noPolar);
n3 = sum(nan1{3} & noPolar);
n4 = sum(nan1{4} & noPolar);
dataStat.percEditSLA = sum(~editSLA(nan1{1} & noPolar))/n1*100;
dataStat.percEditSLAstd = sum(~editSLAstd(nan1{1} & noPolar))/n1*100;
dataStat.percEditIB = sum(~editIB(nan1{1} & noPolar))/n1*100;
dataStat.percBiasedOrbit = sum(kbias(nan1{1} & noPolar))/n1*100;
dataStat.percEditWet = sum(~editWet(nan1{1} & noPolar))/n1*100;
dataStat.percEditDry = sum(~editDry(nan1{1} & noPolar))/n1*100;
dataStat.percEditIono = sum(~editIono(nan1{1} & noPolar))/n1*100;
dataStat.percEditSsb = sum(~editSsb(nan1{1} & noPolar))/n1*100;
dataStat.percEditSigma0SLA = sum(~editSigma0(nan1{1} & noPolar))/n1*100;
dataStat.percEditSigma0stdSLA = sum(~editSigma0std(nan1{1} & noPolar))/n1*100;
dataStat.percEditSigma0 = sum(~editSigma0(nan1{3} & noPolar))/n3*100;
dataStat.percEditSigma0std = sum(~editSigma0std(nan1{3} & noPolar))/n3*100;
dataStat.percEditSWH = sum(~editSWH(nan1{2} & noPolar))/n2*100;
dataStat.percEditSWHstd = sum(~editSWHstd(nan1{2} & noPolar))/n2*100;
dataStat.percEditWsp = sum(~editWsp(nan1{4} & noPolar))/n4*100;
dataStat.percEditAllSLA = sum(~nanNOC{1}(nan1{1} & noPolar))/n1*100;
dataStat.percEditAllSWH = sum(~nanNOC{2}(nan1{2} & noPolar))/n2*100;
dataStat.percEditAllSigma0 = sum(~nanNOC{3}(nan1{3} & noPolar))/n3*100;
% -----------------------------------------------------end editing criteria



%% Compute distance from coast for each point
%if strcmp(data_type,'SIR_GOP_L2')
xh = gshhs.lon;
yh = gshhs.lat;
lev = gshhs.level;

%boundary between Antarctica grounding-line and ocean (level 6) rather than
%Antarctica ice and ocean (level 5)
kl = (lev == 1 | lev == 2 | lev == 6); %include lakes and enclosed seas
xh = xh(kl);
yh = yh(kl);
xh = cell2mat(xh);
yh = cell2mat(yh);
xh = xh(:);
yh = yh(:);
xh = xh(~isnan(xh));
yh = yh(~isnan(yh));
[yh,IX] = sort(yh);
xh = xh(IX);
xh(xh > 180) = xh(xh > 180)-360;

dcoast = distance2Coast(lon(:),lat(:),xh,yh,100);
dcoast = dcoast(:)';
dataStat.distCoast1Hz = dcoast;

tic
dcoast = distance2Coast(hi_lon(:),hi_lat(:),xh,yh,100);
toc
dcoast = reshape(dcoast,size(hi_lon));
dataStat.distCoast20Hz = dcoast;


for j=1:3
    nan_x = nan1{j} & nanNOC{j} & noPolar;
    
    if sum(nan_x) > 0; % added as test 30 Aug 2016
        % compute abs(diff) for SLA
        hi_x = hi_params{j};
        hi_x = hi_x(:,nan_x);
        hi_t = hi_utc(:,nan_x);
        dutc = abs(diff(hi_t(:)));
        diffxy = abs(diff(hi_x(:)));
        diffxy(dutc > 0.1) = NaN;
        diffxy = [NaN;diffxy]; %#ok
        diffxy = reshape(diffxy,20,length(diffxy)/20);
        dataStat.(['absDiff_' fields{j}]) = diffxy;
    else
        dataStat.(['absDiff_' fields{j}]) = NaN(20,1);
    end
end
%end

%% Compute statistics
for i=1:length(params)
    x = params{i};
    dataStat.(['validFlag_' fields{i}]) = nan1{i};
    dataStat.(['nrec_' fields{i}]) = sum(nan1{i});
    nan_x = nan1{i} & noPolar; % exclude Polar regions for statistics
    if i == 5
        dataStat.(['nrecPos_' fields{i}]) = sum(x(nan1{i}) >= 0);
        dataStat.(['nrecPos_noPolar_' fields{i}]) = sum(x(nan_x) >= 0);
    end
    dataStat.(['nrec_noPolar_' fields{i}]) = sum(nan_x);
    
    if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
        x1 = x(nan_x & inLRM);
        x2 = x(nan_x & ~inLRM);
        if i == 5
            x1 = x1(x1 >= 0);
            x2 = x2(x2 >= 0);
        end
        perctile1 = prctile(x1,[5 25 75 95]);
        perctile2 = prctile(x2,[5 25 75 95]);
        dataStat.(['mean_inLRM_' fields{i}]) = mean(x1);
        dataStat.(['mean_outLRM_' fields{i}]) = mean(x2);
        dataStat.(['median_inLRM_' fields{i}]) = median(x1);
        dataStat.(['median_outLRM_' fields{i}]) = median(x2);
        dataStat.(['std_inLRM_' fields{i}]) = std(x1);
        dataStat.(['std_outLRM_' fields{i}]) = std(x2);
        dataStat.(['p5_inLRM_' fields{i}]) = perctile1(1);
        dataStat.(['p25_inLRM_' fields{i}]) = perctile1(2);
        dataStat.(['p75_inLRM_' fields{i}]) = perctile1(3);
        dataStat.(['p95_inLRM_' fields{i}]) = perctile1(4);
        dataStat.(['p5_outLRM_' fields{i}]) = perctile2(1);
        dataStat.(['p25_outLRM_' fields{i}]) = perctile2(2);
        dataStat.(['p75_outLRM_' fields{i}]) = perctile2(3);
        dataStat.(['p95_outLRM_' fields{i}]) = perctile2(4);
        
    end
    if strcmp(data_type,'SIR_FDM_L2') || i == 5
        x = x(nan_x);
        if i == 5
            x = x(x >= 0);
        end
        perctile = prctile(x,[5 25 75 95]);
        dataStat.(['mean_' fields{i}]) = mean(x);
        dataStat.(['median_' fields{i}]) = median(x);
        dataStat.(['std_' fields{i}]) = std(x);
        dataStat.(['p5_' fields{i}]) = perctile(1);
        dataStat.(['p25_' fields{i}]) = perctile(2);
        dataStat.(['p75_' fields{i}]) = perctile(3);
        dataStat.(['p95_' fields{i}]) = perctile(4);
    end
    
    if(i < 5)
        if i ~=4
            hi_x = hi_params{i};
            if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
                hi_x1 = hi_x(:,nan_x & inLRM);
                hi_x2 = hi_x(:,nan_x & ~inLRM);
                hi_t1 = hi_utc(:,nan_x & inLRM);
                hi_t2 = hi_utc(:,nan_x & ~inLRM);
                dutc1 = abs(diff(hi_t1(:)));
                diffxy1 = diff(hi_x1(:));
                diffxy1(dutc1 > 1) = [];
                dutc2 = abs(diff(hi_t2(:)));
                diffxy2 = diff(hi_x2(:));
                diffxy2(dutc2 > 1) = [];
                dataStat.(['noise_inLRM_' fields{i}]) = nanstd(hi_x1);
                dataStat.(['noise_outLRM_' fields{i}]) = nanstd(hi_x2);
                dataStat.(['noiseavg_inLRM_' fields{i}]) = nanmean(nanstd(hi_x1));
                dataStat.(['noiseavg_outLRM_' fields{i}]) = nanmean(nanstd(hi_x2));
                dataStat.(['noiseStd_inLRM_' fields{i}]) = nanstd(nanstd(hi_x1));
                dataStat.(['noiseStd_outLRM_' fields{i}]) = nanstd(nanstd(hi_x2));
                dataStat.(['noiseDiff_inLRM_' fields{i}]) = nanstd(diffxy1)/sqrt(2);
                dataStat.(['noiseDiff_outLRM_' fields{i}]) = nanstd(diffxy2)/sqrt(2);
                dataStat.(['noiseDiffMad_inLRM_' fields{i}]) = nanmedian(abs(diffxy1));
                dataStat.(['noiseDiffMad_outLRM_' fields{i}]) = nanmedian(abs(diffxy2));
            end
            hi_x = hi_x(:,nan_x);
            hi_t = hi_utc(:,nan_x);
            dutc = abs(diff(hi_t(:)));
            diffxy = diff(hi_x(:));
            diffxy(dutc > 1) = [];
            dataStat.(['noise_' fields{i}]) = nanstd(hi_x);
            dataStat.(['noiseavg_' fields{i}]) = nanmean(nanstd(hi_x));
            dataStat.(['noiseStd_' fields{i}]) = nanstd(nanstd(hi_x));
            dataStat.(['noiseDiff_' fields{i}]) = nanstd(diffxy)/sqrt(2);
            dataStat.(['noiseDiffMad_' fields{i}]) = nanmedian(abs(diffxy));
            
        end
        
        
        % precise quantities based on scientific thresholds
        x = params{i};
        nan_x2 =  nanNOC{i};
        if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
            x1 = x(nan_x & nan_x2 & inLRM); % nan_x here excludes polar regions
            x2 = x(nan_x & nan_x2 & ~inLRM);
        end
        x = x(nan_x2 & nan_x); % nan_x excludes polar regions
        
        % --------------------- ONLY FOR VALIDATION -----------------------
        if strcmp(data_type,'SIR_GOP_L2') && i~=3
            f1 = nan_x2 & nan_x;
            
            if i ==1
                ssh = h - range_correc - h_tide_solid;
                dataVal.ssh = ssh(f1); %atm + tides included
                dataVal.mss = h_mss2(f1);
                dataVal.wet = corr_wet_trop_mod(f1);
                dataVal.dry = corr_dry_trop(f1);
                dataVal.iono = corr_iono_gim(f1);
                dataVal.ssb = corr_ssb(f1);
                dataVal.solid = h_tide_solid(f1);
                dataVal.totOcn_tide = h_tot_geocen_ocn_tide_sol1(f1);
                dataVal.poleTide = h_tide_geocen_pole(f1);
                dataVal.atm = corr_atm(f1);
                dataVal.range = range(f1);
                dataVal.alt = h(f1);
            end
            
            dataVal.(fields{i}) = params{i}(f1);
            dataVal.(['x_' fields{i}]) = lon(f1);
            dataVal.(['y_' fields{i}]) = lat(f1);
            dataVal.(['orbit_' fields{i}]) = orbits(f1);
            dataVal.(['t_' fields{i}]) = dates(f1);
            
        end
        
        % -----------------------------------------------END FOR VALIDATION
        
        
        dataStat.(['validNOCPolarIncluded_' fields{i}]) = nan_x2;
        dataStat.(['validNOC_' fields{i}]) = nan_x2 & noPolar; %exclude polar
        perctile = prctile(x,[5 25 75 95]);
        dataStat.(['nrecNOC_' fields{i}]) = length(x);
        if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
            perctile1 = prctile(x1,[5 25 75 95]);
            perctile2 = prctile(x2,[5 25 75 95]);
            dataStat.(['meanNOC_inLRM_' fields{i}]) = mean(x1);
            dataStat.(['meanNOC_outLRM_' fields{i}]) = mean(x2);
            dataStat.(['medianNOC_inLRM_' fields{i}]) = median(x1);
            dataStat.(['medianNOC_outLRM_' fields{i}]) = median(x2);
            dataStat.(['stdNOC_inLRM_' fields{i}]) = std(x1);
            dataStat.(['stdNOC_outLRM_' fields{i}]) = std(x2);
            dataStat.(['p5NOC_inLRM_' fields{i}]) = perctile1(1);
            dataStat.(['p25NOC_inLRM_' fields{i}]) = perctile1(2);
            dataStat.(['p75NOC_inLRM_' fields{i}]) = perctile1(3);
            dataStat.(['p95NOC_inLRM_' fields{i}]) = perctile1(4);
            dataStat.(['p5NOC_outLRM_' fields{i}]) = perctile2(1);
            dataStat.(['p25NOC_outLRM_' fields{i}]) = perctile2(2);
            dataStat.(['p75NOC_outLRM_' fields{i}]) = perctile2(3);
            dataStat.(['p95NOC_outLRM_' fields{i}]) = perctile2(4);
        end
        dataStat.(['meanNOC_' fields{i}]) = mean(x);
        dataStat.(['medianNOC_' fields{i}]) = median(x);
        dataStat.(['stdNOC_' fields{i}]) = std(x);
        dataStat.(['p5NOC_' fields{i}]) = perctile(1);
        dataStat.(['p25NOC_' fields{i}]) = perctile(2);
        dataStat.(['p75NOC_' fields{i}]) = perctile(3);
        dataStat.(['p95NOC_' fields{i}]) = perctile(4);
        if i ~= 4
            hi_x = hi_params{i};
            if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
                hi_x1 = hi_x(:,nan_x & nan_x2 & inLRM);
                hi_x2 = hi_x(:,nan_x & nan_x2 & ~inLRM);
                hi_t1 = hi_utc(:,nan_x2 & nan_x & inLRM);
                hi_t2 = hi_utc(:,nan_x2 & nan_x & ~inLRM);
                dutc1 = abs(diff(hi_t1(:)));
                dutc2 = abs(diff(hi_t2(:)));
                diffxy1 = diff(hi_x1(:));
                diffxy1(dutc1 > 1) = [];
                diffxy2 = diff(hi_x2(:));
                diffxy2(dutc2 > 1) = [];
            end
            hi_x = hi_x(:,nan_x2 & nan_x);
            hi_t = hi_utc(:,nan_x2 & nan_x);
            dutc = abs(diff(hi_t(:)));
            diffxy = diff(hi_x(:));
            diffxy(dutc > 1) = [];
            
            
            if isempty(hi_x)
                dataStat.(['noiseNOC_' fields{i}]) = NaN(1,20);
                dataStat.(['noiseavgNOC_' fields{i}]) = NaN(1,20);
                dataStat.(['noiseStdNOC_' fields{i}]) = NaN(1,20);
                dataStat.(['noiseDiffNOC_' fields{i}]) = [];
                dataStat.(['noiseDiffMadNOC_' fields{i}]) = [];
                
            else
                dataStat.(['noiseNOC_' fields{i}]) = nanstd(hi_x);
                dataStat.(['noiseavgNOC_' fields{i}]) = nanmean(nanstd(hi_x));
                dataStat.(['noiseStdNOC_' fields{i}]) = nanstd(nanstd(hi_x));
                dataStat.(['noiseDiffNOC_' fields{i}]) = nanstd(diffxy)/sqrt(2);
                dataStat.(['noiseDiffMadNOC_' fields{i}]) = nanmedian(abs(diffxy));
            end
            
            
            if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
                if isempty(hi_x)
                    dataStat.(['noiseNOC_inLRM_' fields{i}]) = NaN(1,20);
                    dataStat.(['noiseavgNOC_inLRM_' fields{i}]) =  NaN(1,20);
                    dataStat.(['noiseStdNOC_inLRM_' fields{i}]) = NaN(1,20);
                    dataStat.(['noiseDiffNOC_inLRM_' fields{i}]) = [];
                    dataStat.(['noiseDiffMadNOC_inLRM_' fields{i}]) = [];
                    dataStat.(['noiseNOC_outLRM_' fields{i}]) = [];
                    dataStat.(['noiseavgNOC_outLRM_' fields{i}]) = [];
                    dataStat.(['noiseStdNOC_outLRM_' fields{i}]) = [];
                    dataStat.(['noiseDiffNOC_outLRM_' fields{i}]) = [];
                    dataStat.(['noiseDiffMadNOC_outLRM_' fields{i}]) = [];
                    
                else
                    dataStat.(['noiseNOC_inLRM_' fields{i}]) = nanstd(hi_x1);
                    dataStat.(['noiseavgNOC_inLRM_' fields{i}]) = nanmean(nanstd(hi_x1));
                    dataStat.(['noiseStdNOC_inLRM_' fields{i}]) = nanstd(nanstd(hi_x1));
                    dataStat.(['noiseDiffNOC_inLRM_' fields{i}]) = nanstd(diffxy1)/sqrt(2);
                    dataStat.(['noiseDiffMadNOC_inLRM_' fields{i}]) = nanmedian(abs(diffxy1));
                    dataStat.(['noiseNOC_outLRM_' fields{i}]) = nanstd(hi_x2);
                    dataStat.(['noiseavgNOC_outLRM_' fields{i}]) = nanmean(nanstd(hi_x2));
                    dataStat.(['noiseStdNOC_outLRM_' fields{i}]) = nanstd(nanstd(hi_x2));
                    dataStat.(['noiseDiffNOC_outLRM_' fields{i}]) = nanstd(diffxy2)/sqrt(2);
                    dataStat.(['noiseDiffMadNOC_outLRM_' fields{i}]) = nanmedian(abs(diffxy2));
                end
            end
        end
        
    end
    if i == 1
        % 2D histogram
        hi_x = hi_params{i};
        if strcmp(data_type,'SIR_IOP_L2') || strcmp(data_type,'SIR_GOP_L2')
            nan_xy = nan1{1} & nan1{2} & noPolar & inLRM;
            dataStat.noise_ssha4scatter_inLRM = nanstd(hi_x(:,nan_xy));
            dataStat.nan2DHist_inLRM = nan_xy;
            
            nan_xy = nan1{1} & nan1{2} & noPolar & ~inLRM; % exclude polar and no-LRM regions
            dataStat.noise_ssha4scatter_outLRM = nanstd(hi_x(:,nan_xy));
            dataStat.nan2DHist_outLRM = nan_xy;
        else
            nan_xy = nan1{1} & nan1{2} & noPolar; % exclude polar regions as swh is meaningless
            dataStat.noise_ssha4scatter_inLRM = nanstd(hi_x(:,nan_xy));
            dataStat.nan2DHist_inLRM = nan_xy;
        end
        
        % crossover analysis
        lonx = lon(nan1{i} & nanNOC{i} & noPolar);
        latx = lat(nan1{i} & nanNOC{i} & noPolar);
        tutc = dates(nan1{i} & nanNOC{i} & noPolar);
        orb = orbits(nan1{i} & nanNOC{i} & noPolar);
        kcross = crossOver(lonx,latx,orb);
        if all(size(kcross))
            lonCross = lonx(kcross(1,:));
            latCross = latx(kcross(1,:));
            diffCross = zeros(1,size(kcross,2));
            for z=1:size(kcross,2)
                dt1 = abs(tutc-tutc(kcross(1,z))).*(24*3600) <= 2;
                dt2 = abs(tutc-tutc(kcross(2,z))).*(24*3600) <= 2;
                diffCross(1,z) = abs(median(x(dt1))-median(x(dt2)));
            end
            dataStat.diffCross = diffCross;
        else
            diffCross = NaN;
            lonCross = NaN;
            latCross = NaN;
            dataStat.diffCross = diffCross;
        end
        kthr = diffCross < 2; % outliers >2m
        dataStat.lonCross = lonCross;
        dataStat.latCross = latCross;
        dataStat.meanCross = mean(diffCross(kthr)); % discard outliers
        dataStat.stdCross = std(diffCross(kthr)); % discard outliers
    end
    
    
end

%% compute indices of points that are at the edge of SAR Pacific box
[yp,xp] = polysplit(no_LRM_mask(2,:),no_LRM_mask(1,:));
% find SAR box polygon
%kSAR = cellfun(@(x,y) sum((x>-145 & x<-90) & (y>-30 & y<0)),xp,yp); %Pacific
kSAR = cellfun(@(x,y) sum((x>-13 & x<-2) & (y>-20 & y<-12)),xp,yp);%st Helena
kSAR = find(kSAR ~= 0);
xp = xp{kSAR};
yp = yp{kSAR};

% find points inside/outside SAR Pacific polygon
kin = inPolygonMex([lon;lat],[xp;yp]);
kout = ~kin;
dk = kin(2:end)+kout(1:end-1);
k2 = find(dk == 2);
k0 = find(dk == 0);
if ~isempty(k2)
    kin = [k2+1,k0]; % two closest points to edge
    kout = [k2,k0+1]; % two closest points to edge
    
    % reject pairs of points in which the outsider is in fact far away from the
    % edge due to possible gaps
    dt = abs(dates(kin)-dates(kout)).*24*3600;
    kin = kin(dt < 2);
    kout = kout(dt < 2);
else
    kin = [];
    kout = [];
end
dataStat.kInPacificSAR = kin;
dataStat.kOutPacificSAR = kout;

% check folders exists
if ~exist([path3 day_date(1:4)],'dir'), mkdir([path3 day_date(1:4)]) , end;
if ~exist([path3 day_date(1:4) '/' day_date(5:6)],'dir');
    mkdir([path3 day_date(1:4) '/' day_date(5:6)]) ;
end;



save([path3 day_date(1:4) '/' day_date(5:6) '/Stats_' data_type '_' day_date '.mat'],'-struct','dataStat')

if strcmp(data_type,'SIR_GOP_L2')
    save([path_val 'dataVal_' data_type '_' day_date '.mat'],'-struct','dataVal')
end


