function result2 = tracking_auto_ves(in, nt, dt, fnamestring, dname, threshold)
% =========================================================================
% FUNCTION: tracking_auto_ves
% PURPOSE:
%   1) Reads a sequence of TIFF images starting from index "in" up to "nt".
%   2) Inverts the images (255 - I) and applies a Gaussian filter.
%   3) Converts the filtered image to binary using the specified threshold.
%   4) Detects circles in the binary image using imfindcircles.
%   5) Stores the circles' centers along with the current time in "plotlist".
%   6) Calls a custom function "track" to link detections across frames.
%   7) Splits the tracked data by particle ID and writes each trajectory
%      to a file in a "trajectories" subfolder.
%
% INPUTS:
%   in          -> Initial image index (integer).
%   nt          -> Final image index (integer).
%   dt          -> Time step between images (numeric).
%   fnamestring -> Base filename prefix (string).
%   dname       -> Directory where images are located (string).
%   threshold   -> Threshold for im2bw (numeric).

% NOTES:
%   - The circle detection range is [80, 200]. You may adjust this to match
%     the expected circle radii in your images.
% =========================================================================

%% 1) Read the first image using its index "in"
% Construct the filename with appropriate zero-padding for the index.
if in < 10
    fnamestring2 = sprintf('000%d.tif', in);
    fname        = sprintf('%s%s', fnamestring, fnamestring2);
    I            = imread(fullfile(dname, fname));
elseif in >= 10 && in < 100
    fnamestring2 = sprintf('00%d.tif', in);
    fname        = sprintf('%s%s', fnamestring, fnamestring2);
    I            = imread(fullfile(dname, fname));
elseif in >= 100 && in < 1000
    fnamestring2 = sprintf('0%d.tif', in);
    fname        = sprintf('%s%s', fnamestring, fnamestring2);
    I            = imread(fullfile(dname, fname)); 
else
    % If in >= 1000
    fnamestring2 = sprintf('%d.tif', in);
    fname        = sprintf('%s%s', fnamestring, fnamestring2);
    I            = imread(fullfile(dname, fname));
end 

%% 2) Invert the image and apply filtering
% Invert the image so that circles appear brighter instead of darker.
I3 = 255 - I;

% Apply Gaussian filter (sigma=1) to reduce noise
B  = imgaussfilt(I3, 1);

% Convert to binary using the provided threshold
BW = im2bw(B, threshold);

% Detect circles in the binary image
%   'Sensitivity' controls how permissive the detection is.
%   Adjust the min/max radii [80, 200] to suit your images.
[center, radii] = imfindcircles(BW, [80, 200], 'Sensitivity', 0.95);

% Initialize a time counter (t), and label each detection with time = t
t  = 0;
tt = zeros(size(center,1),1) + t;
pos = [center(:,:), tt];  % Combine centers & time
plotlist = pos;           % 'plotlist' accumulates all detections
t = t + dt;               % Increment time by dt for the next frame

% Clear the temporary variable storing circle centers for clarity
clear center

%% 3) Process subsequent frames
%   The variable "counter" is updated but not explicitly used for anything
%   other than display. You can remove or adjust it if not needed.
rr = 0;
counter = nt - in;

% Loop from the initial index up to nt (final index)
for i = in:nt
    counter = counter - 1
    % Uncomment if you want to see how many iterations remain:
    % disp(['Remaining frames: ', num2str(counter)]);
    
    % Construct the filename for the current index (zero-padded)
    if i < 10
        fnamestring2 = sprintf('000%d.tif', i);
        fname        = sprintf('%s%s', fnamestring, fnamestring2);
        I            = imread(fullfile(dname, fname));
    elseif i >= 10 && i < 100
        fnamestring2 = sprintf('00%d.tif', i);
        fname        = sprintf('%s%s', fnamestring, fnamestring2);
        I            = imread(fullfile(dname, fname));
    elseif i >= 100 && i < 1000
        fnamestring2 = sprintf('0%d.tif', i);
        fname        = sprintf('%s%s', fnamestring, fnamestring2);
        I            = imread(fullfile(dname, fname)); 
    else
        % If i >= 1000
        fnamestring2 = sprintf('%d.tif', i);
        fname        = sprintf('%s%s', fnamestring, fnamestring2);
        I            = imread(fullfile(dname, fname));
    end
    
    % Invert and filter the image again
    I3 = 255 - I;
    B  = imgaussfilt(I3, 1);
    BW = im2bw(B, threshold);
    
    % Detect circles
    [center, radii] = imfindcircles(BW, [80, 200], 'Sensitivity', 0.95);
    
    % Label the detections with the current time
    tt  = zeros(size(center,1),1) + t;
    pos = [center(:,:), tt];
    
    % Add detections for this frame to 'plotlist'
    plotlist = [plotlist; pos]; 
    
    % Increment time
    t = t + dt;
end

%% 4) Track the points across frames
% The "track" function must be available on your MATLAB path.
% The second argument (30) is the max displacement.
result = track(plotlist, 30);

% Extract the total number of rows in the 'result' matrix
m = size(result, 1);

% The last indicates the total number of particles
numpart = result(m, 4); 

% Insert two extra rows of zeros at the end
l = size(result);
result(l(1)+1, :) = 0;
result(l(1)+2, :) = 0;

% Initialize a trajectory index "jj" for saved files
jj = 1;

% 'r' indexes into the partial array of each trajectory
r = 1;

% 's' is the first particle ID encountered in 'result'
s = result(1, 4);

% Create a subfolder named "trajectories" in "dname" if it doesn't exist
mkdir(fullfile(dname, 'trajectories'));

% Iterate through 'result' to separate each particle's trajectory
for n = 1:size(result,1)-1
    
    if s == result(n, 4)
        % Accumulate points for the same particle
        part(r,:) = result(n,:);
        r = r + 1;
    else
        % Encountered a new particle ID
        s = result(n+1, 4);
        
        % Build the filename for this trajectory
        tfname = sprintf('trajectories/trj_ves%d.dat', jj);
        
        fid    = fopen(fullfile(dname, tfname), 'w');
        
        % Write each row of 'part' to the file
        for ii = 1:size(part,1)
            fprintf(fid, '%g\t', part(ii,:));
            fprintf(fid, '\n');
        end
        
        fclose(fid);
        % Increase the trajectory file index
        jj = jj + 1;
        
        % Reset the 'part' array for the next trajectory
        clear part
        r = 1;
    end
end

clear all   
close all   
end
