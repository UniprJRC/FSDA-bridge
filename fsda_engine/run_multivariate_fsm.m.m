load('swiss_banknotes.mat'); 
Y = banknotes; 


[outMCD] = mcd(Y);


[outFSMeda] = FSMeda(Y, outMCD.bsb);

disp('Multivariate FSDA analysis completed successfully.');