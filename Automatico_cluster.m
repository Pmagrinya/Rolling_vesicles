% ===================================================================
% SCRIPT:   Image Analysis and Clustering with DBSCAN
% AUTHOR:   Paula Magrinya
% DATE:     07/03/2024
% PURPOSE:  This script prompts the user for directories containing
%           image sequences, then applies Gaussian filtering and 
%           thresholding to identify dark objects. DBSCAN is used to
%           cluster these dark objects. The user must confirm the 
%           clustering before proceeding. Finally, a tracking script 
%           (tracking_clust_auto) is run for all selected videos.
% NOTE:     Make sure 'tracking_clust_auto.m' is available and in 
%           your MATLAB path.
% ===================================================================

clear all;  % Clears the workspace entirely (variables, MEX links, etc.)

% Initialize empty character arrays to store filenames and directory names.
fnamestring = char([]);
dname       = char([]);

% Specify the number of videos (image sequences) you want to analyze.
prompt = {'Enter number of videos to analyze:'};
dlgtitle = 'Number of Videos';
dims = [1 40];   
definput = {'1'};  
answer = inputdlg(prompt, dlgtitle, dims, definput);

prompt = {'Enter number of videos to analyze:'};
dlgtitle = 'Number of Videos';
dims = [1 40];   
definput = {'1'};  
answer = inputdlg(prompt, dlgtitle, dims, definput);

nv = str2double(answer{1})

% ===================================================================
% LOOP 1: Acquires input for each video sequence (folder of images) 
%         and tests the clustering parameters before tracking.
% ===================================================================

for i = 1:nv

    % ---------------------------------------------------------------
    % Ask the user to select the folder containing the image sequence.
    % ---------------------------------------------------------------
    FF = uigetdir('C:\');         % Opens a dialog to choose a folder path.
    l_dname(i) = length(FF);      % Store the length of the folder path.
    dname = char(dname, FF);      % Build a list (char array) of folder names.

    % ---------------------------------------------------------------
    % Identify all .tif files in the selected directory.
    % ---------------------------------------------------------------
    xdir   = dir(fullfile(dname(i+1, 1:l_dname(i)), '*.tif'));
    nfiles = size(xdir, 1) - 1;   % Number of files (subtract 1 if there's an extra).
    nfstr  = int2str(nfiles);     % Convert number of files to string.
    ndir   = {xdir.name};         % Cell array of filenames.

    % ---------------------------------------------------------------
    % Extract the base file name (assuming specific naming format).
    % Here, 'ss' captures the substring that matches \w+[a-zA-Z_0-9]_\d{4}-\d{2}-\d{2}-\d{6}-.
    % You might need to adjust the regex to match your specific file naming convention.
    % ---------------------------------------------------------------
    ss    = regexp(ndir, '\w+[a-zA-Z_0-9]_\d{4}-\d{2}-\d{2}-\d{6}-', 'match', 'once');
    fstr  = char(ss(1));

    % ---------------------------------------------------------------
    % Prompt the user to confirm or change the number of images, 
    % the starting index, time step, and base file name. 
    % ---------------------------------------------------------------
    prompt = {
        'Enter number of images:', ...
        'Enter initial image number:', ...
        'Enter time step:', ...
        'Enter file name:'
    };
    dlgtitle = 'Input';
    dims     = [1 1 1 1];
    definput = {nfstr, '1', '0.1', fstr};
    answer   = inputdlg(prompt, dlgtitle, dims, definput);

    % ---------------------------------------------------------------
    % Store the user inputs for this video.
    % ---------------------------------------------------------------
    nt(i)   = str2double(answer(1)); % Number of images in sequence
    in(i)   = str2double(answer(2)); % Initial image index
    dt(i)   = str2double(answer(3)); % Time step between images
    fstr    = char(answer(4));       % File name string
    fnamestring = char(fnamestring, fstr);

    % ---------------------------------------------------------------
    % Clustering parameter selection & verification loop.
    % The script shows one image (the first in the sequence) and 
    % plots the DBSCAN results. The user is asked to confirm if 
    % the clustering is acceptable; if not, it re-prompts for new
    % clustering parameters.
    % ---------------------------------------------------------------
    good = false;  % Flag to ensure user approves clustering parameters.

    while ~good

        % Clear temporary variables related to clustering:
        clear pk;

        % -----------------------------------------------------------
        % Prompt the user for image filtering and clustering parameters:
        %   - binary threshold
        %   - epsilon (distance threshold in DBSCAN)
        %   - mints (minimum points in a cluster in DBSCAN)
        % -----------------------------------------------------------
        prompt = {'binary threshold', 'epsilon', 'mints'};
        dlgtitle = 'Input';
        dims     = [1 1 1];
        % Default parameters shown; these should be adjusted to your setup.
        definput = {'0.55', '5', '5'};
        answer   = inputdlg(prompt, dlgtitle, dims, definput);

        % Parse user inputs for clustering:
        threshold(i) = str2double(answer(1));
        epsilon(i)   = str2double(answer(2));
        mints(i)     = str2double(answer(3));

        % -----------------------------------------------------------
        % Read the first image of the sequence based on its index 
        % (in(i)). This part of the code constructs a filename with 
        % leading zeros as needed.
        % -----------------------------------------------------------
        if in(i) < 10
            fnamestring2 = sprintf('000%d.tif', in(i));
            fname = sprintf('%s%s', fnamestring(i+1, 1:27), fnamestring2);
            I = imread(fullfile(dname(i+1, 1:l_dname(i)), fname));
        elseif in(i) > 9 && in(i) < 100
            fnamestring2 = sprintf('00%d.tif', in(i));
            fname = sprintf('%s%s', fnamestring(i+1, 1:27), fnamestring2);
            I = imread(fullfile(dname(i+1, 1:l_dname(i)), fname));
        elseif in(i) > 99 && in(i) < 1000
            fnamestring2 = sprintf('0%d.tif', in(i));
            fname = sprintf('%s%s', fnamestring(i+1, 1:27), fnamestring2);
            I = imread(fullfile(dname(i+1, 1:l_dname(i)), fname));
        else
            fnamestring2 = sprintf('%d.tif', in(i));
            fname = sprintf('%s%s', fnamestring(i+1, 1:27), fnamestring2);
            I = imread(fullfile(dname(i+1, 1:l_dname(i)), fname));
        end

        % Show basic info about the image in the console:
        whos I;

        % -----------------------------------------------------------
        % Process the image:
        %   1) Gaussian filter to reduce noise (imgaussfilt)
        %   2) Convert to binary using the chosen threshold
        % -----------------------------------------------------------
        B  = imgaussfilt(I, 1);         % Apply Gaussian smoothing with sigma=1
        BW = im2bw(B, threshold(i));    % Convert the smoothed image to binary

        % -----------------------------------------------------------
        % Locate the dark pixels in the binary image.
        %   'm' and 'n' are arrays of row and column indices 
        %   where BW == 0 (dark in the binary image).
        % -----------------------------------------------------------
        [m, n] = find(BW == 0);
        pk = [n, m];  % Store the points as (x, y) = (column, row)

        % -----------------------------------------------------------
        % Apply DBSCAN clustering to the dark pixels:
        %   idx: cluster labels assigned to each point in 'pk'
        % -----------------------------------------------------------
        idx = dbscan(pk, epsilon(i), mints(i));

        % -----------------------------------------------------------
        % Display the original image (grayscale) and overlay 
        % the clustered points, each cluster in different colors.
        % -----------------------------------------------------------
        figure(1)
        colormap('gray');
        imshow(I);
        hold on;
        gscatter(pk(:,1), pk(:,2), idx);  % DBSCAN clusters overlay

        % Title for the figure
        title('DBSCAN Using Euclidean Distance Metric');

        % -----------------------------------------------------------
        % Ask the user if the image analysis looks good. 
        % If "Yes", we accept parameters. Otherwise, we loop again.
        % -----------------------------------------------------------
        promptMessage = sprintf('Is Image Analysis acceptable?');
        titleBarCaption = 'Yes or No';
        button = questdlg(promptMessage, titleBarCaption, 'Yes', 'No', 'Yes');

        if strcmpi(button, 'Yes')
            good = true;
        else
            good = false;
        end

    end % End while loop

    % Close the figure used for previewing clustering
    close all

end % End for loop (videos input)

% ===================================================================
% LOOP 2: Runs the tracking program for all the videos using 
%         the confirmed parameters.
% ===================================================================
for i = 1:nv
    try
        % ----------------------------------------------------------------
        % Call the external function "tracking_clust_auto" with the 
        % parameters selected earlier. Make sure that the function 
        % signature matches the arguments below, or adjust as necessary:
        %    tracking_clust_auto(inVal, dtVal, ncycVal, fileStr, ...
        %                        dirName, thresholdVal, epsilonVal, mintsVal)
        %
        % NOTE: The variable ncyc(i) was referenced here but not 
        %       defined in the script above. Make sure ncyc(i) is 
        %       defined or remove it if not needed.
        % ----------------------------------------------------------------
        tracking_clust_auto( ...
            in(i), ...
            dt(i), ...
            nt(i), ...
            fnamestring(i+1, 1:27), ...
            dname(i+1, 1:l_dname(i)), ...
            threshold(i), ...
            epsilon(i), ...
            mints(i) ...
        );

    catch exception
        % ----------------------------------------------------------------
        % Catch the exception if tracking does not work. 
        % This avoids stopping the entire script if one video fails.
        % ----------------------------------------------------------------
        disp(['Error in interaction ', num2str(i), ': ', exception.message]);
    end
end



