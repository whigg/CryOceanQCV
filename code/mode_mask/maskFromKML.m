clear all
fn = dir('/noc/users/cryo/QCV_Cryo2/code/mode_mask/Mask*5.kml');
s = kml_shapefile(fn(1).name);
x = cell(length(s),1);
y = cell(length(s),1);
for i=1:length(s)
    x{i} = s(i).X;
    y{i} = s(i).Y;
end


% --------------- build mode mask with distinction of modes ---------------
dir1 = '/noc/users/cryo/QCV_Cryo2/code/mode_mask/';
load([dir1 'seasMask_polar.mat'])
modes = load([dir1 'zonesNameMode.mat']);
modes = modes.Z;

% split polygon 'CP40_003-00' into two
for i=1:length(x)
    if(strfind(s(i).name,'CP40_003-00'))
        ksplit = i;
    end
end
x1 = x{ksplit};
y1 = y{ksplit};
x1(y1 > 80) = [];
y1(y1 > 80) = [];
x2 = x1(x1 > 0);
y2 = y1(x1 > 0);
y1 = y1(x1 < 0);
x1 = x1(x1 < 0);
x1(end+1) = x1(1);
y1(end+1) = y1(1);
x{ksplit} = x1;
y{ksplit} = y1;
x{length(x)+1} = x2;
y{length(y)+1} = y2;
modes(end+1).name = {'CP40_003-02'};
modes(end).mode = {'SAR'};
modes(end).priority = 4;


% --------------- remove zones so that modes and s coincide ---------------
% ------- modes is based on Mask 3.6 and contains more zones than s -------
ks = [2 21];
km = [2:24 43:65 78 79 127 134:140];
modes(km) = [];
x(ks) = [];
y(ks) = [];
s(ks) = [];
%------------------------------------------------------- end removing zones


% find CYSSAR01 and CYSSAR02 polygons
ct = 0;
knorth = zeros(length(x),1);
ksouth = zeros(length(x),1);
for i=1:length(x)-1
    if(strfind(s(i).name,'CYSSAR01'))
        ct = ct+1;
        knorth(ct) = i;
    end
    if(strfind(s(i).name,'CYSSAR02'))
        ct = ct+1;
        ksouth(ct) = i;
    end
    
end
knorth(knorth == 0) = [];
ksouth(ksouth == 0) = [];


for k=1:24
    X = x;
    Y = y;
    mo = modes;
    pole = polar{k};
    [yp,xp] = polysplit(pole(2,:),pole(1,:));
    X{knorth(1)} = xp{1};
    Y{knorth(1)} = yp{1};
    X{ksouth(1)} = xp{2};
    Y{ksouth(1)} = yp{2};
    mo = rmfield(mo,'name');
    Mode = [mo(:).mode];
    p = [mo(:).priority];
        
    seasMaskModes.(['seas_' sprintf('%1.2d',k)]).X = X;
    seasMaskModes.(['seas_' sprintf('%1.2d',k)]).Y = Y;
    seasMaskModes.(['seas_' sprintf('%1.2d',k)]).mode = Mode;
    seasMaskModes.(['seas_' sprintf('%1.2d',k)]).priority = p;
end
% -------------------------------------------------------------------------


% % find LRM polygons
% xlrm = cell(length(x),1);
% ylrm = cell(length(x),1);
% ct = 0;
% klrm = zeros(length(x),1);
% for i=1:length(x)
%     if(strfind(s(i).name,'LRM'))
%         ct = ct+1;
%         klrm(ct) = i;
%         xlrm{ct} = s(i).X;
%         ylrm{ct} = s(i).Y;
%     end
% end
% klrm(klrm == 0) = [];
% k = cellfun(@isempty,xlrm);
% xlrm(k) = [];
% ylrm(k) = [];
% x(klrm) = [];
% y(klrm) = [];
% s(klrm) = [];
% 
% 
% % polygons for Arctic (CYSSAR01) and Antarctica (CYSSAR02) are updated
% % twice a month, hence there will be 2 mode masks every month
% 
% % find CYSSAR01 and CYSSAR02 polygons
% ct = 0;
% knorth = zeros(length(x),1);
% ksouth = zeros(length(x),1);
% for i=1:length(x)
%     if(strfind(s(i).name,'CYSSAR01'))
%         ct = ct+1;
%         knorth(ct) = i;
%     end
%     if(strfind(s(i).name,'CYSSAR02'))
%         ct = ct+1;
%         ksouth(ct) = i;
%     end
%     
% end
% knorth(knorth == 0) = [];
% ksouth(ksouth == 0) = [];
% 
% % load seasonal Arctic and Antarctica polygons
% fn = dir('/noc/users/cryo/QCV_Cryo2/code/mode_mask/Seasonal*.kml');
% s2 = kml_shapefile(fn(1).name);
% xnorth = cell(24,1);
% ynorth = cell(24,1);
% xsouth = cell(24,1);
% ysouth = cell(24,1);
% for i=1:24
%     xnorth{i} = s2(i).X;
%     ynorth{i} = s2(i).Y;
%     xsouth{i} = s2(i+24).X;
%     ysouth{i} = s2(i+24).Y;
% end
% 
% % split polygon 'CP40_003-00' into two
% x1 = x{71};
% y1 = y{71};
% x1(y1 > 80) = [];
% y1(y1 > 80) = [];
% x2 = x1(x1 > 0);
% y2 = y1(x1 > 0);
% y1 = y1(x1 < 0);
% x1 = x1(x1 < 0);
% x1(end+1) = x1(1);
% y1(end+1) = y1(1);
% x{71} = x1;
% y{71} = y1;
% x{length(x)+1} = x2;
% y{length(y)+1} = y2;
% 
% xpole = cell(24,1); % seasonal Arctic polygons
% ypole = cell(24,1);
% for k=1:24
%     disp(k)
%     X = x;
%     Y = y;
%     
%     xpole{k} = [xnorth{k};NaN;xsouth{k};NaN];
%     ypole{k} = [ynorth{k};NaN;ysouth{k};NaN];
%     X{knorth(1)} = xnorth{k};
%     Y{knorth(1)} = ynorth{k};
%     X{ksouth(1)} = xsouth{k};
%     Y{ksouth(1)} = ysouth{k};
%     X([knorth(2:end) ksouth(2:end)]) = [];
%     Y([knorth(2:end) ksouth(2:end)]) = [];
%     
%     % compute unions between all no-LRM polygons
%     K = cell(length(X),1);
%     for i=1:length(X)
%         for j=1:length(X)
%             [xi,~] = polybool('&',X{i},Y{i},X{j},Y{j});
%             if ~isempty(xi)
%                 K{i} = [K{i} j];
%             end
%         end
%     end
%     
%     xi = [];
%     yi = [];
%     for i=1:length(X)
%         for j=1:length(K{i})
%             [xi,yi] = polybool('union',xi,yi,X(K{i}(j)),Y(K{i}(j)));
%         end
%     end
%     [xi,yi] = poly2cw(xi,yi);
%     
%     % remove continental ice sheets areas where LRM is operated
%     for i=1:length(xi)
%         for j=1:length(xlrm)
%             [xi{i},yi{i}] = polybool('minus',xi{i},yi{i},xlrm{j},ylrm{j});
%         end
%     end
%     [yi,xi] = polyjoin(yi,xi);
%     xi(end+1) = NaN; %#ok
%     yi(end+1) = NaN; %#ok
%     z = [xi';yi'];
%     seasMask.(['seas_' sprintf('%1.2d',k)]) = z;
% end
%save seasMask_noLRM_3_5.mat seasMask -mat

%[f,v] = poly2fv(xi,yi);
% % Display the patch.
%patch('Faces', f, 'Vertices', v, 'FaceColor', 'blue', ...
%  'EdgeColor', 'none');
% axis off, axis equal