% =========================================================================
% SCRIPT:   main.m
% PURPOSE:
%   1) Prompt the user to choose whether to track Particles or Vesicles.
%   2) Depending on the selection, call the script "Atomatico_cluster.m" 
%      or "automatico_ves.m".
% =========================================================================


% Ask the user what they want to track
choice = questdlg('What do you want to track?', ...        
                  'Tracking Selection', ...                 
                  'Particles', 'Vesicles', 'Cancel', ...     
                  'Cancel');                                 

switch choice
    case 'Particles'
        % -----------------------------------------------------------------
        % Call the script "Atomatico_cluster.m"
        % -----------------------------------------------------------------
       
        run('Atomatico_cluster.m');
        
    case 'Vesicles'
        % -----------------------------------------------------------------
        % Call the script "automatico_ves.m"
        % -----------------------------------------------------------------
        
        Automatico_ves;
        
    otherwise
        % The user canceled or closed the dialog
        disp('Operation canceled.');
end

% You could add any additional instructions here if needed.
disp('End of main script execution.');
