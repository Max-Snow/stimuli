function ex = codebar_whitenoise(ex, replay)
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
    rs = getrng(me.seed);

  else

    % shortcut for parameters
    me = ex.stim{end}.params;

    % initialize the VBL timestamp
    vbl = GetSecs();

    % initialize random seed
    if isfield(me, 'seed')
      rs = getrng(me.seed);
    else
      rs = getrng();
    end
    ex.stim{end}.seed = rs.Seed;

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
    
    % store timestamps
    ex.stim{end}.timestamps = zeros(ex.stim{end}.numframes,1);

  end
  
  quotient = idivide(uint32(numframes), uint32(num_contrast_frames));
  remainer = rem(numframes, num_contrast_frames);
  contrasts = rand(rs, quotient, 1) * (me.contrast_h - me.contrast_l) + me.contrast_l;
  contrasts = upsample_s(contrasts, num_contrast_frames, 1);
  contrasts = cat(1, contrasts, ones(remainer, 1) * rand(rs) * (me.contrast_h - me.contrast_l) + me.contrast_l);

  % loop over frames
  for fi = 1:numframes + 1
  
    % generate stimulus pixels
    if fi == numframes + 1
      contrast_now = contrasts(fi-1, 1);
    else
      contrast_now = contrasts(fi, 1);
    end  
    
    if strcmp(me.dist, 'gaussian')
      frame = 1 + contrast_now * randn(rs, me.ndims(1), 1);
    elseif strcmp(me.dist, 'uniform')
      % this is actually uniformly distributed
      frame = 2 * rand(rs, me.ndims(1), 1) * contrast_now + (1 - contrast_now);
    elseif strcmp(me.dist, 'binary')
      % true binary would be
      frame = floor(2 * rand(rs, me.ndims(1), 1)) * contrast_now + (1 - contrast_now);
    else
      error(['Distribution ' me.dist ' not recognized! Must be gaussian or binary.']);
    end
    
    frame = repmat(frame, 1, me.ndims(2));

    if replay
      if fi == numframes + 1
	  continue
      end

      % write the frame to the hdf5 file
      h5write(ex.filename, [ex.group '/stim'], uint8(me.gray * frame), [1, 1, fi], [me.ndims, 1]);

    else

      % make the texture
      texid = Screen('MakeTexture', ex.disp.winptr, uint8(ex.disp.gray * frame));

      % draw the texture, then kill it
      Screen('DrawTexture', ex.disp.winptr, texid, [], ex.disp.dstrect, 0, 0);
      Screen('Close', texid);

      % update the photodiode with the top left pixel on the first frame
      if fi == 1
        pd = ex.disp.white;
        vbl = GetSecs();
        init_vbl = vbl;
      elseif fi == numframes + 1
        pd = ex.disp.white;
      else
        pd = 0;
      end
      Screen('FillOval', ex.disp.winptr, pd, ex.disp.pdrect);

      % flip onto the scren
      Screen('DrawingFinished', ex.disp.winptr);
      vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);

      % save the timestamp
      ex.stim{end}.timestamps(fi) = vbl - init_vbl;

      % check for ESC
      ex = checkkb(ex);
      if ex.key.keycode(ex.key.esc)
        fprintf('ESC pressed. Quitting.')
        break;
      end

    end

  end
  
  if ~replay
    
    Screen('FillRect', ex.disp.winptr, ex.disp.gray, ex.disp.dstrect);
    Screen('FillOval', ex.disp.winptr, 0, ex.disp.pdrect);
    vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);
    pause(1);
  end

end
