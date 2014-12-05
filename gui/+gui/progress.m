function progress
    global PROGRESS FIG
    
    FIG.progress = waitbar( ...
        0, '' ...
      , 'visible', 'off' ...
    );

    PROGRESS.timer = timer;
    PROGRESS.timer.StartDelay = 2;
    PROGRESS.timer.TimerFcn = @hide;

    function update( fraction, title, message )
        set( FIG.progress ...
          , 'visible', 'on' ...
          , 'name', title ...
        );
        waitbar( fraction, FIG.progress, message );
        
        if ( fraction == 1 )
            start( PROGRESS.timer );
        else
            stop( PROGRESS.timer );
        end
    end
    PROGRESS.update = @update;
    
    
    function hide( varargin )
        if ishandle( FIG.progress )
            set( FIG.progress, 'visible', 'off' );
        end
    end
end