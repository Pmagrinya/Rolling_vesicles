function resultados = tracking_clust_auto(in, dt, nt, fnamestring, dname, threshold, epsilon, mints)
% =====================================================================
% FUNCTION: tracking_clust_auto
% PURPOSE:  1) Reads a sequence of TIFF images starting from index "in".
%           2) Performs image filtering and binary thresholding.
%           3) Identifies dark pixel clusters via DBSCAN (dbscan function).
%           4) Computes the centroid of each cluster for every frame.
%           5) Tracks these centroids across frames using a custom 
%              function "track".
%           6) Saves the resulting trajectories to .dat files.
%
% INPUTS:
%   in          -> The initial image index (integer).
%   dt          -> Time step between frames (numeric).
%   nt          -> The last (or total) image index (integer).
%   fnamestring -> The base file-name prefix (string).
%   dname       -> The directory where images are located (string).
%   threshold   -> Binary threshold for image segmentation (numeric).
%   epsilon     -> The epsilon value for DBSCAN (distance threshold).
%   mints       -> Minimum points for DBSCAN to form a cluster.
%
% =====================================================================

%% 1) Read the first image in the sequence
% Construct a filename with the correct zero-padding based on the index "in".
if in < 10
    fnamestring2 = sprintf('000%d.tif', in);
    fname = sprintf('%s%s', fnamestring, fnamestring2);
    I = imread(fullfile(dname, fname));
elseif in >= 10 && in < 100
    fnamestring2 = sprintf('00%d.tif', in);
    fname = sprintf('%s%s', fnamestring, fnamestring2);
    I = imread(fullfile(dname, fname));
elseif in >= 100 && in < 1000
    fnamestring2 = sprintf('0%d.tif', in);
    fname = sprintf('%s%s', fnamestring, fnamestring2);
    I = imread(fullfile(dname, fname));
else
    fnamestring2 = sprintf('%d.tif', in);
    fname = sprintf('%s%s', fnamestring, fnamestring2);
    I = imread(fullfile(dname, fname));
end

%% 2) Filter and threshold the first image, then cluster via DBSCAN
B  = imgaussfilt(I, 1);          % Apply Gaussian filter (sigma=1) to reduce noise
BW = im2bw(B, threshold);        % Convert to binary using the specified threshold

% Identify dark pixels (where BW == 0) and store in pk as (x, y)
[m, n] = find(BW == 0);
pk     = [n, m];

% Use DBSCAN to cluster these points:
%   idx = cluster labels for each point; points with label -1 are outliers
idx = dbscan(pk, epsilon, mints);

% Initialize time counter
t = 0;

% Combine pk with their cluster labels
pk = [pk, idx];

% Separate the points by their cluster labels
r = 1;
for j = 1:size(pk,1)
    clust(r,:) = pk(j,:);
    r = r + 1;
end

% Compute the centroid (mean x and y) for each cluster
r  = 1;
ss = 1;
while r <= max(clust(:,3))
    j = 1;
    for iTemp = 1:size(clust,1) 
        if clust(iTemp,3) == r
            clust_temp(j,:) = clust(iTemp,:);
            j = j + 1;
        end
    end
    CM(ss,:) = [mean(clust_temp(:,1)), mean(clust_temp(:,2))];
    r  = r + 1;
    ss = ss + 1;
    clear clust_temp;
end

% Store time = 0 (or the initial time) in the third column
tt = zeros(size(CM,1), 1);
tt = tt + t;

% Combine centroids and time into pos
pos      = [CM(:,:) tt];
plotlist = pos;

% Update time for the next frame
t = t + dt;

% Clear variables related to the first frame
clear pk clust CM

%% 3) Process subsequent frames from in up to nt
for i = in:nt

    % Construct the filename (zero-padded) for the current index
    if i < 10
        fnamestring2 = sprintf('000%d.tif', i);
        fname = sprintf('%s%s', fnamestring, fnamestring2);
        I = imread(fullfile(dname, fname));
    elseif i >= 10 && i < 100
        fnamestring2 = sprintf('00%d.tif', i);
        fname = sprintf('%s%s', fnamestring, fnamestring2);
        I = imread(fullfile(dname, fname));
    elseif i >= 100 && i < 1000
        fnamestring2 = sprintf('0%d.tif', i);
        fname = sprintf('%s%s', fnamestring, fnamestring2);
        I = imread(fullfile(dname, fname));
    elseif i >= 1000 && i < 10000
        fnamestring2 = sprintf('%d.tif', i);
        fname = sprintf('%s%s', fnamestring, fnamestring2);
        I = imread(fullfile(dname, fname));
    end
    
    % Repeat the filtering, thresholding, and clustering steps
    B  = imgaussfilt(I, 1);
    BW = im2bw(B, threshold);
    [m, n] = find(BW == 0);
    pk = [n, m];
    
    idx = dbscan(pk, epsilon, mints);
    pk  = [pk, idx];
    
    r = 1;
    for j = 1:size(pk,1)
        clust(r,:) = pk(j,:);
        r = r + 1;
    end
    
    % If 'clust' was successfully created, compute centroids:
    if exist('clust','var') == 1
        r  = 1;
        ss = 1;
        while r <= max(clust(:,3))
            j = 1;
            for mn = 1:size(clust,1)
                if clust(mn,3) == r
                    clust_temp(j,:) = clust(mn,:);
                    j = j + 1;
                end
            end
            CM(ss,:) = [mean(clust_temp(:,1)), mean(clust_temp(:,2))];
            r  = r + 1;
            ss = ss + 1;
            clear clust_temp;
        end
        
        % Create time column for these centroids
        tt = zeros(size(CM,1),1);
        tt = tt + t;
        
        % Optional: visualize clusters
        %gscatter(clust(:,1), clust(:,2), clust(:,3));  
        
        % Append centroid positions to plotlist
        pos      = [CM(:,:) tt ];
        plotlist = [plotlist; pos];  
        
        % Update time
        t = t + dt;
        
        % Clear variables for next iteration
        clear pk clust CM
    
    else
        % If no clusters were found, just update time
        tt = tt + t;  
        clear pk clust CM
    end

end

%% 4) Call a "track" function to link centroids across frames
%    NOTE: "track" must be defined elsewhere in your MATLAB path.
%    The second argument (30) has to be the maximum distance travelled by
%    the particle
result = track(plotlist, 30);

% Obtain the size of the result array
m = size(result, 1);
% Number of particles found
numpart = result(m,4);  

% Append zeros to 'result' 
result(end+1, :) = 0;
result(end+2, :) = 0;

% Prepare for splitting results by particle ID
r = 1;
jj=1;
s = result(1,4);

% Create a subfolder called "trajectories" in dname for saving output
mkdir(fullfile(dname, 'trajectories'));

% Loop through 'result' to separate each particle's trajectory
for n = 1:size(result,1)-1
    
    if s == result(n,4)
        % Accumulate points for the same particle
        part(r,:) = result(n,:);
        r = r + 1;
    else
        % If we encounter a new particle ID, we save the old one's data
        s = result(n+1,4);

        tfname = sprintf('trajectories/trj%d.dat', jj);
        fid    = fopen(fullfile(dname, tfname), 'w');
        
        % Write each row of 'part' to the file
        for ii = 1:size(part,1)
            fprintf(fid, '%g\t', part(ii,:));
            fprintf(fid, '\n');
        end
        
        fclose(fid);
        
        % Reset indexing for the next trajectory
        jj=jj+1;
        clear part
        r = 1;
    end
end

% Clean up at the end of the function 
clear all
close all

end % End of function
