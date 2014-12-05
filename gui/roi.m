function roi

    global SLM ROI AX

    % select a region of interest
    ROI.width = 240; ROI.height = 240;
    ROI.size = [ ROI.height ROI.height ];
    ROI.offset = ( SLM.size - ROI.size ) / 2;
    ROI.center = ROI.size / 2 + ROI.offset;
    
    ROI.edges = [ ROI.offset( 2 ) ROI.offset( 2 )                  ROI.offset( 2 ) + ROI.width + 1  ROI.offset( 2 ) + ROI.width + 1 ROI.offset( 2 )
                  ROI.offset( 1 ) ROI.offset( 1 ) + ROI.height + 1 ROI.offset( 1 ) + ROI.height + 1 ROI.offset( 1 )                 ROI.offset( 1 ) ];
    
    ROI.index = false( SLM.size );
    ROI.index( ...
        ( 1 : ROI.height ) + ROI.offset( 1 ) ...
      , ( 1 : ROI.width ) + ROI.offset( 2 ) ...
    ) = true;


    function result = hit( x, y )
        result = ( ( x > ROI.offset( 2 ) ) && ( x <= ROI.offset( 2 ) + ROI.width ) ) ...
              && ( ( y > ROI.offset( 1 ) ) && ( y <= ROI.offset( 1 ) + ROI.height ) );
    end
    ROI.hit = @hit;
    
    function result = select( image )
        result = image( ...
            ( 1 : ROI.height ) + ROI.offset( 1 ) ...
          , ( 1 : ROI.width ) + ROI.offset( 2 ) ...
        );
    end
    ROI.select = @select;
    
    
    function display
        plot( AX.roi, ROI.edges( 1, : ), ROI.edges( 2, : ), 'g' );
    end
    ROI.display = @display;
end