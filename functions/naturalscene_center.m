function ex = naturalscene_center(ex, replay)
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

    % set the random seed
    rs = getrng(me.seed);

  else

    % shorthand for parameters
    me = ex.stim{end}.params;

    % initialize random seed
    if isfield(me, 'seed')
      rs = getrng(me.seed);
    else
      rs = getrng();
    end
    ex.stim{end}.seed = rs.Seed;
    %if isfield(me, 'seed')
    %  rand('seed', me.seed);
    %  randn('seed', me.seed);
    %end

    % compute flip times from the desired frame rate and length
    if me.framerate > ex.disp.frate
        error('Your monitor does not support a frame rate higher than %i Hz', ex.disp.frate);
    end
    flipsPerFrame = round(ex.disp.frate / me.framerate);
    ex.stim{end}.framerate = 1 / (flipsPerFrame * ex.disp.ifi);
    flipint = ex.disp.ifi * (flipsPerFrame - 0.5);

    % store the number of frames
    numframes = ceil((me.length * 60) * ex.stim{end}.framerate);
    ex.stim{end}.numframes = numframes;
    
    % store timestamps
    ex.stim{end}.timestamps = zeros(ex.stim{end}.numframes+1,1);


  end

  % load natural images
  files = dir(fullfile(me.imgdir, me.imgext));
  numimages = length(files);
  images = cell(numimages, 1);
  for fileidx = 1:numimages
    images(fileidx) = struct2cell(load(fullfile(me.imgdir, files(fileidx).name)));
  end
  
  % loop over frames
  for fi = 1:numframes + 1

    % pick a new image
    if mod(fi, me.jumpevery) == 1
      img = rescale(images{randi(rs, numimages)});
      xstart = randi(rs, size(img,1) - 2*me.ndims(1)) + me.ndims(1);
      ystart = randi(rs, size(img,2) - 2*me.ndims(2)) + me.ndims(2);

    % jitter
    else

      xstart = max(min(size(img,1) - me.ndims(1), xstart + round(me.jitter * randn(rs, 1))), 1);
      ystart = max(min(size(img,2) - me.ndims(2), ystart + round(me.jitter * randn(rs, 1))), 1);

    end

    % get the new frame
    color = 2 * img(xstart + idivide(me.ndims(1), int32(2)), ystart + idivide(me.ndims(2), int32(2))) * me.contrast + (1 - me.contrast);

    if replay
      
      if fi == numframes + 1
          continue
      end

      % write the frame to the hdf5 file
      h5write(ex.filename, [ex.group '/stim'], uint8(ones(me.ndims) * me.gray * color), [1, 1, fi], [me.ndims, 1]);

    else

      Screen('FillRect', ex.disp.winptr, ex.disp.gray * color, ex.disp.dstrect);

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
    
    Screen('FillRect', ex.disp.winptr, ex.disp.gray, ex.disp.dstrect);
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