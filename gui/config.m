function config

    global CONFIG

    % camera
    CONFIG.display = 'image';
    
    % io
    CONFIG.dataPath = '../data';
    
    % slm
    CONFIG.wavelength = 515;
    CONFIG.blankSLM = false;
    
    % target
    CONFIG.transform.shift.x = 0;
    CONFIG.transform.shift.y = 0;
    CONFIG.transform.scale.x = 1;
    CONFIG.transform.scale.y = 1;
    CONFIG.transform.angle = 0;
    
    % controller
    CONFIG.maxIterations = 20;
    CONFIG.autoIterate = false;
end