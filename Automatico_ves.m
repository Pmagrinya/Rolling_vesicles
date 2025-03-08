% ===================================================================
% SCRIPT:   Circle Detection & Tracking Setup
% AUTHOR:   Paula Magrinya
% DATE:     07/03/2024
% PURPOSE:  This script allows the user to select a directory of
%           TIFF images, prompts for some basic parameters, and uses
%           imfindcircles to detect circular objects in an inverted 
%           and filtered version of the image. The user must confirm 
%           if the detection is acceptable; if not, the script re-prompts.
%           Finally, it calls the tracking function tracking_auto_ves 
%           for each selected video.
% NOTE:     Make sure 'tracking_auto_ves.m' is in your MATLAB path.
% ===================================================================

clear all;  % Clears all variables and functions from memory.

% Initialize empty character arrays for filenames and directory names.
fnamestring = char([]);
dname       = char([]);

% Define how many "videos" (image sequences) you want to process.
prompt = {'Enter number of videos to analyze:'};
dlgtitle = 'Number of Videos';
dims = [1 40];   
definput = {'1'}; 
answer = inputdlg(prompt, dlgtitle, dims, definput);

nv = str2double(answer{1});

% ===================================================================
% LOOP 1: Gather user inputs for each image sequence, detect circles 
%         in a single preview image, and confirm detection parameters.
% ===================================================================
for i = 1:nv

    % ---------------------------------------------------------------
    % Prompt user to select a folder containing the .tif image files.
    % ---------------------------------------------------------------
    FF = uigetdir('C:\');            % Opens folder browser starting at C:\
    l_dname(i) = length(FF);         % Length of the selected directory path.
    dname = char(dname, FF);         % Build a list of directory names.

    % ---------------------------------------------------------------
    % Identify all .tif files in this directory and parse filenames.
    % ---------------------------------------------------------------
    xdir   = dir(fullfile(dname(i+1, 1:l_dname(i)), '*.tif'));
    nfiles = size(xdir, 1) - 1;      % Number of .tif files found (adjusted by -1 if needed).
    nfstr  = int2str(nfiles);        % Convert the number of files to string.
    ndir   = {xdir.name};            % Cell array containing file names.

    % ---------------------------------------------------------------
    % Extract a substring of the filename assuming a specific 
    % format using regex. Adjust the pattern to match your file naming.
    % ---------------------------------------------------------------
    ss   = regexp(ndir, '\w+[a-zA-Z_0-9]_\d{4}-\d{2}-\d{2}-\d{6}-', 'match', 'once'); 
    fstr = char(ss(1));  % Base filename string (if it exists)

    % ---------------------------------------------------------------
    % Prompt for basic sequence parameters:
    %   - Number of images (nt)
    %   - Initial image index (in)
    %   - Time step (dt)
    %   - Base file name (fstr)
    % ---------------------------------------------------------------
    prompt = {
        'Enter number of images:', ...
        'Enter initial image number:', ...
        'Enter time step:', ...
        'Enter file name:'
    };
    dlgtitle = 'Input';
    dims     = [1 1 1 1];
    definput = {nfstr, '0', '0.1', fstr};  % Default values
    answer   = inputdlg(prompt, dlgtitle, dims, definput);

    % Store inputs in arrays for each video.
    nt(i)   = str2double(answer{1});  % Number of images in sequence
    in(i)   = str2double(answer{2});  % Initial image index
    dt(i)   = str2double(answer{3});  % Time step
    fstr    = char(answer{4});        % Base file name
    fnamestring = char(fnamestring, fstr);

    % Set a flag to check if the user is satisfied with detection results.
    good = false;

    % ===================================================================
    % LOOP 1.1: Preview circle detection in the first image of the set, 
    %           allowing the user to adjust threshold until acceptable.
    % ===================================================================
    while ~good
        
        % Clear any old variables related to circle detection
        clear h
        
        % -----------------------------------------------------------
        % Prompt user for binary threshold for circle detection.
        % Adjust as needed depending on your image brightness/contrast.
        % -----------------------------------------------------------
        prompt    = {'binary threshold'};
        dlgtitle  = 'Input';
        dims      = [1];
        definput  = {'0.15'};  % Default threshold for example
        answer    = inputdlg(prompt, dlgtitle, dims, definput);

        % Convert string to numerical value for threshold.
        threshold(i) = str2double(answer{1});

        % -----------------------------------------------------------
        % Construct the full filename (with leading zeros if needed) 
        % for the initial image (in(i)).
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

        % Display image info in the command window:
        whos I;

        % -----------------------------------------------------------
        % Invert the image so that circles appear bright. 
        % (255 - I) assumes an 8-bit image (0-255 range).
        % -----------------------------------------------------------
        I3 = 255 - I;

        % -----------------------------------------------------------
        % Apply Gaussian filtering to reduce noise.
        % Then create a binary image based on 'threshold(i)'.
        % -----------------------------------------------------------
        B  = imgaussfilt(I3, 1);             % Gaussian blur with sigma=1
        BW = im2bw(I3, threshold(i));        % Convert to binary

        % -----------------------------------------------------------
        % Detect circles using imfindcircles on the binary image.
        %   - [50, 200] is the range of possible radii. 
        %   - 'Sensitivity' controls detection sensitivity, adjust as needed.
        % -----------------------------------------------------------
        [center, radii] = imfindcircles(BW, [50, 200], 'Sensitivity', 0.95);

        % -----------------------------------------------------------
        % Display the original (non-inverted) image and overlay circles.
        % -----------------------------------------------------------
        figure(2)
        colormap('gray');
        imshow(I);
        h = viscircles(center, radii);  
        hold on;

        % -----------------------------------------------------------
        % Ask the user if the circle detection looks acceptable.
        % If "Yes", exit the loop. If "No", prompt for threshold again.
        % -----------------------------------------------------------
        promptMessage = sprintf('Is the circle detection acceptable?');
        titleBarCaption = 'Yes or No';
        button = questdlg(promptMessage, titleBarCaption, 'Yes', 'No', 'Yes');
        if strcmpi(button, 'Yes')
            good = true;
        else
            good = false;
        end
    end % End while (~good)

end % End for (i = 1:nv)

% ===================================================================
% LOOP 2: Run the tracking script for each "video" using the 
%         parameters gathered.
% ===================================================================
for i = 1:nv
    try
        % Call the function 'tracking_auto_ves' with your parameters.
        % Make sure the function signature matches these arguments.
        tracking_auto_ves( ...
            in(i), ...
            nt(i), ...
            dt(i), ...
            fnamestring(i+1, 1:27), ...
            dname(i+1, 1:l_dname(i)), ...
            threshold(i) ...
        );
    catch exception
        % If an error occurs, display it and move on to the next video.
        disp(['Error in iteration ', num2str(i), ': ', exception.message]);
    end
end
