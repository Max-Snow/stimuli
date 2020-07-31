function ex = whitenoise(ex, replay)
%
% ex = whitenoise(ex, replay)
%
% Required parameters:
%   length : float (length of the experiment in minutes)
%   framerate : float (rough framerate, in Hz)
%   ndims : [int, int] (dimensions of the stimulus)
%   dist: 'gaussian' or 'binary'
%
% Optional parameters:
%   seed : int (for the random number generator. Default: 0)
%
% Runs a receptive field mapping stimulus

  if replay

    % load experiment properties
    numframes = ex.numframes;
    me = ex.params;

    % set the random seed
    %rs = getrng(me.seed);

  else

    % shortcut for parameters
    me = ex.stim{end}.params;

    % initialize the VBL timestamp
    vbl = GetSecs();

    % initialize random seed
    %if isfield(me, 'seed')
    %  rs = getrng(me.seed);
    %else
    %  rs = getrng();
    %end
    %ex.stim{end}.seed = rs.Seed;
    if isfield(me, 'seed')
      rand('seed', me.seed);
      randn('seed', me.seed);
    end    

    % compute flip times from the desired frame rate and length
    if me.framerate > ex.disp.frate
        error('Your monitor does not support a frame rate higher than %i Hz', ex.disp.frate);
    end
    flipsPerFrame = round(ex.disp.frate / me.framerate);
    ex.stim{end}.framerate = 1 / (flipsPerFrame * ex.disp.ifi);
    flipint = ex.disp.ifi * (flipsPerFrame - 0.25);

    % store the number of frames
    numframes = ceil(me.length * ex.stim{end}.framerate);
    num_contrast_frames = ceil(me.contrast_length * ex.stim{end}.framerate);
    ex.stim{end}.numframes = numframes;
    ex.stim{end}.num_contrast_frames = num_contrast_frames;
    
    % store timestamps
    ex.stim{end}.timestamps = zeros(ex.stim{end}.numframes,1);

  end
  
  colors = randn(numframes, 1);
  quotient = idivide(numframes, num_contrast_frames);
  remainer = rem(numframes, num_contrast_frames);
  contrasts = repelem(rand(quotient, 1), num_contrast_frames);
  contrasts = cat(1, contrasts, ones(remainer, 1) * rand);
  colors = colors .* contrasts * ex.disp.gray + ex.disp.gray;
  colors = max(colors, ex.disp.black);
  colors = min(colors, ex.disp.white);

  % loop over frames
  for fi = 1:numframes + 1    

    if replay && fi < numframes + 1

      % write the frame to the hdf5 file
      h5write(ex.filename, [ex.group '/stim'], uint8(ones(me.ndims) * colors(fi, 1)), [1, 1, fi], [me.ndims, 1]);

    else
      if fi == 1
        Screen('FillRect', ex.disp.winptr, colors(fi, 1), ex.disp.dstrect);
        Screen('FillOval', ex.disp.winptr, ex.disp.white, ex.disp.pdrect);
        vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);
      elseif fi == numframes + 1
        Screen('FillRect', ex.disp.winptr, colors(fi - 1, 1), ex.disp.dstrect);
        Screen('FillOval', ex.disp.winptr, ex.disp.white, ex.disp.pdrect);
        vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);
      else
        Screen('FillRect', ex.disp.winptr, colors(fi, 1), ex.disp.dstrect);
        Screen('FillOval', ex.disp.winptr, 0.5 * colors(fi, 1), ex.disp.pdrect);
        vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);
      end
      
      % save the timestamp
      ex.stim{end}.timestamps(fi) = vbl;

      % check for ESC
      ex = checkkb(ex);
      if ex.key.keycode(ex.key.esc)
        fprintf('ESC pressed. Quitting.')
        break;
      end

    end

  end
  if isfield(me, 'seed')
    rand('seed', 'reset');
    randn('seed', 'reset');
  end
end
