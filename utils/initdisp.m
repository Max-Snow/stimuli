function ex = initdisp(ex)
%
% FUNCTION ex = initdisp(ex)
%
% Initialize the display. 

% Make sure PTB is working
AssertOpenGL;

% Check 'ex' struct for background color
if ~isfield(ex.disp, 'bgcol')
  ex.disp.bgcol = 127.5 .* ones(1, 3);
end

% Get the screen numer
ex.disp.screen = max(Screen('Screens'));

% Initialize the OpenGL pipeline, set debugging
InitializeMatlabOpenGL;
Screen('Preference', 'VisualDebugLevel', 3);

% Setup PsychImaging pipeline, allows for fast drawing
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');

% Open the window, fullscreen is default
[ex.disp.winptr, ex.disp.winrect] = PsychImaging('OpenWindow', ...
  ex.disp.screen, ex.disp.bgcol);

% Gamma correction 08/24/2020
load /home/dlee/Documents/MATLAB/visual-stimuli/d239/calibration/20-08-18_gamma_DL.mat
[oldTable, sc] = Screen('LoadNormalizedGammaTable', ex.disp.winptr, g1 * [1 1 1]);

% Setup alpha-blending
Screen('BlendFunction', ex.disp.winptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

% Hide the on screen cursor
HideCursor();

% Screen info
ex.disp.ifi    		= Screen('GetFlipInterval', ex.disp.winptr);
ex.disp.frate  		= round(1 / ex.disp.ifi);
ex.disp.nominalifi	= 1 / ex.disp.frate;
ex.disp.winctr 		= ex.disp.winrect(3:4) ./ 2 + [0, 50];
ex.disp.info   		= Screen('GetWindowInfo', ex.disp.winptr);

% Colors
ex.disp.white = WhiteIndex(ex.disp.screen);
ex.disp.black = BlackIndex(ex.disp.screen);
ex.disp.gray  = (ex.disp.white + ex.disp.black) / 2;

% Set some text properties
Screen('TextFont', ex.disp.winptr, 'Helvetica');
Screen('TextSize', ex.disp.winptr, 24);

% Describe photodiode
ex.disp.pdscale = 0.6;					% Scale factor for the photodiode signal
ex.disp.pdctr   = [0.90 0.15];
ex.disp.pdsize  = SetRect(0, 0, 150, 150);
ex.disp.pdrect  = CenterRectOnPoint(ex.disp.pdsize, ...
  ex.disp.winrect(3) * ex.disp.pdctr(1), ...
  ex.disp.winrect(4) * ex.disp.pdctr(2));

% the destination rectangle
ex.disp.aperturesize = 512;                 	% Size of stimulus aperture
ex.disp.dstrect      = CenterRectOnPoint(...	% Stimulus destination rectangle
  [0 0 ex.disp.aperturesize ex.disp.aperturesize], ...
  ex.disp.winctr(1), ex.disp.winctr(2));

% Microns per pixel
ex.disp.umperpix = 50 / 9;

% missed flips
ex.disp.missedflips = [];
