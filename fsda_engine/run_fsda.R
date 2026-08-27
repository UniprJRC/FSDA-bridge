library(reticulate)

use_python("C:/Users/HP/AppData/Local/Programs/Python/Python313/python.exe", required = TRUE)

run_r_fsda_workflow <- function() {
  message("Starting MATLAB Engine via Python bridge in R...")
  
  matlab <- import("matlab.engine")
  eng <- matlab$start_matlab()
  
  folder_path <- normalizePath("C:/Users/HP/Documents/GitHub/FSDA-bridge/fsda_engine")
  
  eng$cd(folder_path, nargout = 0L)
  eng$addpath(folder_path, nargout = 0L)
  
  message("Running FSDA multivariate workflow (MCD & FSMeda) in R...")
  
  eng$eval("
    data = load('swiss_banknotes.mat');
    
    if isfield(data, 'banknotes')
        raw_data = data.banknotes;
    elseif isfield(data, 'swiss_banknotes')
        raw_data = data.swiss_banknotes;
    else
        vars = fieldnames(data);
        raw_data = data.(vars{1});
    end

    if istable(raw_data)
        Y = table2array(raw_data);
    else
        Y = double(raw_data);
    end

    [outMCD] = mcd(Y);
    
    if isfield(outMCD, 'bsb')
        bsb = outMCD.bsb;
    else
        p = size(Y, 2);
        bsb = (1:(p+1))';
    end

    [outFSMeda] = FSMeda(Y, bsb, 'plots', 1);
    
    drawnow;
    saveas(gcf, 'fsda_output_plot_r.png');
    savefig('fsda_output_plots_r.fig');
    
    disp('R-side multivariate FSDA analysis completed successfully.');
  ", nargout = 0L)
  
  message("R Test passed successfully!")
  eng$quit()
}

run_r_fsda_workflow()