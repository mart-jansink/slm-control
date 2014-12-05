function result

    global RESULT AX CONFIG LINEOUT
    
    RESULT.hdr      = [];
    RESULT.image    = [];
    RESULT.snapshot = [];
        
    function display( source )
        if ( nargin == 0 )
            source = CONFIG.display;
        end
        
        if ~isempty( RESULT.( source ) )
            imshow( RESULT.( source ), [], 'parent', AX.image );
            
            LINEOUT.display( [], source );
            drawnow;
        end
    end
    RESULT.display = @display;
    
    function analyze
        
    end
    RESULT.analyze = @analyze;
end