function util

    global UTIL CONFIG SLM ROI
    
    function toggle( element, field, callback )
        if ( ~isempty( field ) )
            field = strsplit( field, '.' );
            CONFIG = setfield( CONFIG, field{ : }, get( element, 'value' ) );
        end
        
        if ( nargin == 3 )
            callback();
        end
    end
    UTIL.toggle = @toggle;
    
    function step( element, key, step, field, callback )
        direction = [];
        if strcmp( key.Key, 'downarrow' )
            direction = -1;
        elseif strcmp( key.Key, 'uparrow' )
            direction = +1;
        elseif strcmp( key.Key, 'return' )
            % ..disable and enable the element to force it to loose focus..
            set( element, 'enable', 'off' );
            drawnow;
            set( element, 'enable', 'on' );
            drawnow;
            
            direction = 0;
        end
        
        if ( ~isempty( key.Modifier ) && strcmp( key.Modifier{ 1 }, 'shift' ) )
            step = step * 10;
        end
        
        if ~isempty( direction )
            value = str2double( get( element, 'string' ) ) + direction * step;
            value = max( min( value, get( element, 'max' ) ), get( element, 'min' ) );
            
            if ( direction == 0 )
                % ..with no change in value, MATLAB ignores the next string
                % and keeps the new line caused by the return key;
                % therefore, first set it to an empty string..
                set( element, 'string', '' );
            end
            
            set( element, 'string', num2str( value ) );
            
            if ( ~isempty( field ) )
                field = strsplit( field, '.' );
                CONFIG = setfield( CONFIG, field{ : }, value );
            end

            if ( nargin == 5 )
                callback();
            end
        end
    end
    UTIL.step = @step;
    
    
    function fill( element, field, callback )
        value = str2double( get( element, 'string' ) );
            
        if ( ~isempty( field ) )
            field = strsplit( field, '.' );
            CONFIG = setfield( CONFIG, field{ : }, value );
        end

        if ( nargin == 3 )
            callback();
        end
    end
    UTIL.fill = @fill;
    
    
    function [ means, counts ] = incrementalMean( means, counts, values )
        % find the indices of all non-NaN values..
        index = ~isnan( values );
        % ..update the mean values for those indices..
        means( index ) = means( index ) ...
            + ( values( index ) - means( index ) ) ./ counts( index );
        % ..and increment their counts..
        counts( index ) = counts( index ) + 1;
    end
    UTIL.incrementalMean = @incrementalMean;
    
    
    function image = clip( image, th, tw )
        if ( nargin == 1 )
            th = ROI.height; tw = ROI.width;
        end        
        
        [ ih, iw ] = size( image );
        
        if ( ih > th )
            image = image( ( ( 1:th ) + floor( ( ih - th ) / 2 ) ), : );
        elseif ( ih < th )
            temp = zeros( th, iw, 'like', image );
            temp( ( ( 1:ih ) + floor( ( th - ih ) / 2 ) ), : ) = image;
            image = temp;
        end

        if ( iw > tw )
            image = image( :, ( ( 1:tw ) + floor( ( iw - tw ) / 2 ) ) );
        elseif ( iw < tw )
            temp = zeros( th, tw, 'like', image );
            temp( :, ( ( 1:iw ) + floor( ( tw - iw ) / 2 ) ) ) = image;
            image = temp;
        end
    end
    UTIL.clip = @clip;
    
end