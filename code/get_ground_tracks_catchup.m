clear ; clc
%path2Tracks = '/Volumes/noc/users/cryo/QCV_Cryo2/code/groundTracks/';
path2Tracks = '/noc/users/cryo/QCV_Cryo2/code/groundTracks/catchup/';
fln = dir([path2Tracks 'ground*.mat']);
fln = struct2cell(fln);
fln = fln(1,:)';
% flast = fln{end};
f = ftp('calval-pds.cryosat.esa.int','ground','tracks');
cd(f,'GroundTracks/');
dirn_ALL = dir(f,'Full*');

n = 1 ;
dirn = dirn_ALL(n).name;
cd(f,dirn);
dirn = dir(f,'*2sec*'); %this will be the name of the most recent file
% disp('downloading most recent file...')
mget(f,dirn.name,path2Tracks);
disp('done downloading')
close(f);

disp('unzipping file...')
system(['unzip ' [path2Tracks dirn.name] ' -d' path2Tracks]) %extract file using external unzipper (Matlab slow)
disp('done unzipping')

disp('reading file...')

% this does not necessarily unzip the file we expect
% (ie name is different)

txt_fn = ls([path2Tracks '*.txt']) ;
txt_fn(txt_fn == 10)=[] ; % removes carriage return

fid = fopen(txt_fn,'r');
fgets(fid); fgets(fid); fgets(fid);
A = fscanf(fid,'%u- %u- %u_ %u: %u: %u %*c %u %f %*c %f %f',[1,Inf]);
A = reshape(A,10,length(A)/10);
A(7,:) = [];
fclose(fid);
disp('done reading file')

delete(txt_fn)

delete([path2Tracks dirn.name])

k0 = find(A(4,:) == 0 & A(5,:) == 0 & (A(6,:) == 0 | A(6,:) ==1),1,'first');
A0 = A(:,1:(k0-1));

% -------------------------------------------------------------------------

A = A(:,k0:end);
d0 = datenum(A(1,1),A(2,1),A(3,1));
df = datenum(A(1,end),A(2,end),A(3,end));
d = d0:df;
ds = datestr(d,'yyyymmdd');
ds = cellstr(ds);
dsExist = cellfun(@(x) x(end-11:end-4),fln,'unif',0);
dnew = setdiff(ds,dsExist); % update only new files

if ~isempty(dnew)
    B = A;
    clear A
    dateni = datenum(dnew,'yyyymmdd');
    daten = datenum(B(1,:),B(2,:),B(3,:));
    for i=1:length(dnew)
        ki = (daten == dateni(i));
        A = B(:,ki);
        save([path2Tracks 'groundTrack_' dnew{i} '.mat'],'A','-mat');
    end
    
end
clear A B d d0 daten dateni df ki dnew dsExist fid fln txt_fn ds  dirn A0 i k0 n f

for n = 2:4 ;
    f = ftp('calval-pds.cryosat.esa.int','ground','tracks');
    cd(f,'GroundTracks/');
    
    
    dirn = dirn_ALL(n).name;
    cd(f,dirn);
    dirn = dir(f,'*2sec*'); %this will be the name of the most recent file
    % disp('downloading most recent file...')
    mget(f,dirn.name,path2Tracks);
    disp('done downloading')
    close(f);
    
    disp('unzipping file...')
    system(['unzip ' [path2Tracks dirn.name] ' -d' path2Tracks]) %extract file using external unzipper (Matlab slow)
    disp('done unzipping')
    
    disp('reading file...')
    
    % this does not necessarily unzip the file we expect
    % (ie name is different)
    
    txt_fn = ls([path2Tracks '*.txt']) ;
    txt_fn(txt_fn == 10)=[] ; % removes carriage return
    
    fid = fopen(txt_fn,'r');
    fgets(fid); fgets(fid); fgets(fid);
    A = fscanf(fid,'%u- %u- %u_ %u: %u: %u %*c %u %f %*c %f %f',[1,Inf]);
    A = reshape(A,10,length(A)/10);
    A(7,:) = [];
    fclose(fid);
    disp('done reading file')
    
    delete(txt_fn)
    
    delete([path2Tracks dirn.name])
    
    k0 = find(A(4,:) == 0 & A(5,:) == 0 & (A(6,:) == 0 | A(6,:) ==1),1,'first');
    A0 = A(:,1:(k0-1));
    
    % the last day in the ground track files is not complete so we need to
    % update the file corresponding to the last day
    if ~isempty(A0)
        B = A;
        clear A
        d0 = datenum(B(1,1),B(2,1),B(3,1));
        
        
        
        fln = dir([path2Tracks 'ground*.mat']);
        fln = struct2cell(fln);
        fln = fln(1,:)';
        flast = fln{end};
        
        
        
        
        
        
        if d0 == datenum(flast(end-11:end-4),'yyyymmdd')
            a = load([path2Tracks flast]);
            a = a.A;
            A = [a A0]; %#ok
            save([path2Tracks flast],'A','-mat');
        end
        A = B;
        clear B
    end
    % -------------------------------------------------------------------------
    
    A = A(:,k0:end);
    d0 = datenum(A(1,1),A(2,1),A(3,1));
    df = datenum(A(1,end),A(2,end),A(3,end));
    d = d0:df;
    ds = datestr(d,'yyyymmdd');
    ds = cellstr(ds);
    dsExist = cellfun(@(x) x(end-11:end-4),fln,'unif',0);
    dnew = setdiff(ds,dsExist); % update only new files
    
    if ~isempty(dnew)
        B = A;
        clear A
        dateni = datenum(dnew,'yyyymmdd');
        daten = datenum(B(1,:),B(2,:),B(3,:));
        for i=1:length(dnew)
            ki = (daten == dateni(i));
            A = B(:,ki);
            save([path2Tracks 'groundTrack_' dnew{i} '.mat'],'A','-mat');
        end; clear i
        
    end
    clear A B d d0 daten dateni df ki dnew dsExist fid fln txt_fn ds flast dirn A0 k0  f
    
end; clear n















