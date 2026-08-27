import matlab.engine
import os
import warnings

warnings.filterwarnings('ignore', category=UserWarning, module='matlab')

print("Starting MATLAB Engine...")
eng = matlab.engine.start_matlab()

folder_path = os.path.abspath(r"C:\Users\HP\Documents\GitHub\FSDA-bridge\fsda_engine")

print(f"Adding path to MATLAB: {folder_path}")
eng.cd(folder_path, nargout=0)
eng.addpath(folder_path, nargout=0)

print("Running script content and saving plots properly...")
eng.eval("""
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

    % FSMeda run karte waqt plot option ko on rakhein
    [outFSMeda] = FSMeda(Y, bsb, 'plots', 1);
    
    % Figures ko poori tarah draw hone ka waqt dein
    drawnow;
    
    % Ab fig file ke sath-sath standard PNG image bhi save kar lein taaki seedha dikh jaye
    saveas(gcf, 'fsda_output_plot.png');
    savefig('fsda_output_plots.fig');
    
    disp('Multivariate FSDA analysis and plots saved successfully.');
""", nargout=0)

print("Done! Check your fsda_engine folder for fsda_output_plot.png")
eng.quit()