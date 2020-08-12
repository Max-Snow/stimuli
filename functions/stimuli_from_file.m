function ex = stimuli_from_file(ex, replay)
%
% ex = naturalscene(ex, replay)
%
% Required parameters:
%   length : float (length of the experiment in minutes)
%   framerate : float (rough framerate, in Hz)
%   ndims : [int, int] (dimensions of the stimulus)
%   imgdir: string (location of the images)
%   imgext: string (file extension for the images)
%   jumpevery: int (number of frames to wait before jumping to a new image)
%   jitter: strength of jitter
%
% Optional parameters:
%   seed : int (for the random number generator. Default: 0)
%
% Runs a receptive field mapping stimulus
  

  if replay

    % load experiment properties
    numframes = ex.numframes;
    me = ex.params;
    stimulus = load(fullfile(me.stim_dir, me.stim_name));

  else

    % shorthand for parameters
    me = ex.stim{end}.params;
    stimulus = load(fullfile(me.stim_dir, me.stim_name)).stim;


    % compute flip times from the desired frame rate and length
    if me.framerate > ex.disp.frate
        error('Your monitor does not support a frame rate higher than %i Hz', ex.disp.frate);
    end
    flipsPerFrame = round(ex.disp.frate / me.framerate);
    ex.stim{end}.framerate = 1 / (flipsPerFrame * ex.disp.ifi);
    flipint = ex.disp.ifi * (flipsPerFrame - 0.5);

    % store the number of frames
    numframes = size(stimulus)(1);
    ex.stim{end}.numframes = numframes;
    
    % store timestamps
    ex.stim{end}.timestamps = zeros(ex.stim{end}.numframes+1,1);


  end
  
  % loop over frames
  for fi = 1:numframes + 1
  
    if fi == numframes + 1
      frame = squeeze(stimulus(fi-1,:,:));
    else
      frame = squeeze(stimulus(fi,:,:));
    end

    if replay
      
      if fi == numframes + 1
          continue
      end

      % write the frame to the hdf5 file
      h5write(ex.filename, [ex.group '/stim'], uint8(frame), [1, 1, fi], [me.ndims, 1]);

    else

      % make the texture
      texid = Screen('MakeTexture', ex.disp.winptr, frame);

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
        exit;
      end

    end

  end
  if ~replay
    
    Screen('FillRect', ex.disp.winptr, 0, ex.disp.dstrect);
    Screen('FillOval', ex.disp.winptr, 0, ex.disp.pdrect);
    vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);
    pause(1);
  end

end

function xn = rescale(x)
  xmin = min(x(:));
  xmax = max(x(:));
  xn = (x - xmin) / (xmax - xmin);
end
