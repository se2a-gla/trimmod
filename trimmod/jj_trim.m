function ...
  [x_tr, u_tr, d_tr, y_tr, varargout] = ...
  jj_trim (...
  sys, ...
  x, u, d, y, ...
  i_x, i_u, i_d, i_y, ...
  x_nam, u_nam, d_nam, y_nam, ...
  del_x_max, del_u_max, ...
  del_x_lin, del_u_lin, ...
  options)

%JJ_TRIM   Trim point determination of a nonlinear ordinary differential equation system
%
%   [X_TR, U_TR, D_TR, Y_TR] = JJ_TRIM (SYS, X, U, D, Y, I_X, I_U, I_D, I_Y, X_NAM, U_NAM, D_NAM, Y_NAM)
%   trims the system SYS towards an operating point defined by the elements of
%   X (state vector), U (input vector), D (derivative of the state vector),
%   and Y (output vector).
%   I_X and I_U define the indices of the so-called trim variables, which
%   are those states and inputs the trim algorithm has to find
%   the appropriate values for. Specified values of the trim variables
%   are taken as initial starting guesses for the iteration.
%   I_D and I_Y are the indices of the so-called trim requirements, which
%   the trim algorithm has to satisfy. The values of the other D(i) and Y(i)
%   do not matter.
%   X_NAM, U_NAM, D_NAM, and Y_NAM are cell arrays of the form
%   X_NAM = {'state_1'; 'state_2'; ...}
%   containing the names of the states, inputs, derivatives, and outputs.
%   The names can be chosen arbitrarily. They are used only to identify
%   linear dependent trim variables or trim requirements.
%
%   IMPORTANT: o There have to be as many trim variables as there are
%                trim requirements.
%
%              o All vectors (and cell arrays) have to be column vectors.
%
%   To see more help, enter TYPE JJ_TRIM.

%   [X_TR, U_TR, D_TR, Y_TR, ERRFLG] = JJ_TRIM (SYS, ...)
%   ERRFLG = 0 if trimming was successful,
%   ERRFLG = 1 if an error occurred during trimming.
%              The returned trim result is invalid.
%
%   [X_TR, ...] = JJ_TRIM (..., Y_NAM, DEL_X_MAX, DEL_U_MAX)
%   allows the additional specification of maximum alterations
%   of state and input during one trim step.
%   The lengths of DEL_X_MAX and DEL_U_MAX are equal to those of
%   X and U respectively.
%   The default values of DEL_X_MAX and DEL_U_MAX are 1e42.
%
%   [X_TR, ...] = JJ_TRIM (..., DEL_U_MAX, DEL_X_LIN, DEL_U_LIN)
%   allows the additional specification of the state and input step size
%   to be used for the calculation of the Jacobian-matrix (sensitivity matrix)
%   in the linearization procedure.
%   The default values of DEL_X_LIN and DEL_U_LIN are
%   1e-6*(1 + abs(x)) and 1e-6*(1 + abs(u)) respectively.
%
%   [X_TR, ...] = JJ_TRIM (..., DEL_U_LIN, OPTIONS)
%   allows the additional specification of
%   the maximum number of iterations "OPTIONS(1)" (default: 42) and
%   the cost value "OPTIONS(2)" (default: 1e-9) to be gained.

%   Copyright 2000-2004, J. J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de


%   Version 1.5     07.11.2011
%
%   Array initialization warning suppressed.
%   Minor code optimizations.


%   Version 1.2.4   15.10.2008, W. Moennich, DLR-FT
%
%   Comment added:
%   % The functionalities used here ('compile', 'term', ...)
%   % are documented in the Simulink manual under Simulation Commands/model
%   % and in Help(doc) unter Simulink/Functions/Simulation/model.


%   Version 1.2.3   20.05.2003, W. Moennich, DLR-FT
%
%   Optional error flag as 5th output.


%   Version 1.2.2   26.09.2001, W. Moennich, DLR-FT
%
%   Empty vectors now possible for DEL_X_MAX, DEL_U_MAX, DEL_X_LIN, DEL_U_LIN.


%   Version 1.2.1   29.08.2001, W. Moennich, DLR-FT
%
%   Check for maximum number of iterations moved inside the loop.


%   Version 1.2     26.05.2000
%
%   The names of inputs, ... outputs for the error messages
%   are now transferred via the parameter list.
%
%   The precompilation and the release of the system is now done in JJ_TRIM.

% Initialize error flag
errflg = 0;

% Open the system blockdiagram internally
% This dummy evaluation opens the system internally,
% without bringing the system blockdiagram to front
[~, ~, ~] = eval (sys);
    
% Supress the array initialization warning
set_param (sys, 'InitInArrayFormatMsg', 'None');

% Feed through all initial vectors, 
% usefull in case of an emergency exit
x_tr = x;
u_tr = u;
d_tr = d;
y_tr = y;

% Determine lengths of basic vectors
n_x  = length (x);
n_d  = length (d);

n_i_x = length (i_x);
n_i_u = length (i_u);
n_i_y = length (i_y);
n_i_d = length (i_d);

% Assemble generalized input vector and generalized output vector
x_u = [x; u];
d_y = [d; y];

% Determine length of generalized input vector
n_x_u = length (x_u);

% Assemble trim variable index vector and trim requirement index vector
i_t_v = [i_x; i_u + n_x]; 
i_t_r = [i_d; i_y + n_d];

% Determine number of trim variables and trim requirements
n_t_v = n_i_x + n_i_u;
n_t_r = n_i_y + n_i_d;

% There have to be as many trim variables as there are trim requirements
if n_t_r ~= n_t_v
  
  l1 = ['The number of trim variables: ', int2str(n_t_v)];
  l2 = 'does not equal';
  l3 = ['the number of trim requirements: ', int2str(n_t_r)];
  l4 = ' ';
  l5 = 'The returned trim point is not valid.';
  h1 = 'Error';
  errordlg ({l1; l2; l3; l4; l5}, h1); 
  
  % Set errorflag
  errflg = 1;
  
  % If a 5th output parameter is used
  if nargout > 4
    
    % Return errorflag as 5th parameter
    varargout(1) = {errflg};
    
  end
  
  % Game over
  return
  
end

% There should be at least one trim variable and one trim requirement
if ~n_t_r
  
  l1 = 'There should be at least';
  l2 = 'one trim variable and';
  l3 = 'one trim requirement.';
  h1 = 'Nothing to trim';
  warndlg ({l1; l2; l3}, h1);
  
end

% If no maximum step sizes have been defined,
if nargin < 14 || isempty(del_x_max) || isempty(del_u_max)
  
  % set defaults
  del_max = 1.e42*ones (n_x_u, 1); 
  
  % otherwise assemble generalized maximum step vector
else
  
  del_max = [del_x_max; del_u_max];
  
end

% If no step sizes for the linearization have been defined,
if nargin < 16 || isempty(del_x_lin) || isempty(del_u_lin)
  
  % set defaults
  del_lin = 1e-6*(1 + abs(x_u)); 
  
  % otherwise assemble generalized linearization step vector
else
  
  del_lin = [del_x_lin; del_u_lin];
  
end

% If no options have been defined, 
if nargin < 18
  
  % set defaults (maximum number of iterations and cost value to be gained)
  options(1) = 42;
  options(2) = 1e-9;
  
end

% Save and rename the options 
n_iter   = options(1);
cost_tbg = options(2);

% Set time to zero explicitely (assume a time invariant system)
t = 0;

% Set old cost value to infinity, in oder to definitely have 
% an improvement with the first try
cost_old = inf;

% Precompile system.
% Unfortunately, this is necessary because only precompiled systems can be evaluated.
% If the trim algorithm is aborted without the corresponding "Release system" command
% the next precompilation attempt will lead to an error and the simulation cannot
% be started.
% The system then has to be released manually (maybe more than once!) with:
% model_name ([], [], [], 'term')
% The functionalities used here ('compile', 'term', ...) 
% are documented in the Simulink manual under Simulation Commands/model
% and in Help(doc) unter Simulink/Functions/Simulation/model.
feval (sys, [], [], [], 'compile');
    
% Loop over maximum n_iter iterations
for i_iter = 0 : n_iter
  
  % Calculate outputs and derivatives at the current trim point.
  % Important: We have to calculate the outputs first!
  %            The derivatives would be wrong otherwise.
  % Unbelievable but true: Mathworks argues that this is not a bug but a feature!
  % And furthermore: Sometimes it is even necessary to do the output calculation twice
  % before you get the correct derivatives!
  % Mathworks says, they will take care of that problem in one of the next releases...
  y_tr = feval (sys, t, x_u(1:n_x), x_u(n_x+1:end), 'outputs'); 
  y_tr = feval (sys, t, x_u(1:n_x), x_u(n_x+1:end), 'outputs'); 
  d_tr = feval (sys, t, x_u(1:n_x), x_u(n_x+1:end), 'derivs');
  d_y_tr = [d_tr; y_tr];
  
  % Calculate differences between required and current generalized output vectors
  del_d_y = d_y - d_y_tr;
  
  % Pick trim requirements only
  del_t_r = del_d_y(i_t_r);
  
  % Cost value is the maximum element of the trim requirement error vector
  cost = max (abs (del_t_r));
  
  % Cost is an empty matrix if there are no trim variables and trim requirements
  if isempty (cost)
    cost = 0;
  end
  
  % If current cost value has become smaller 
  % than the cost value to be gained
  if cost < cost_tbg
    
    % Output cost value and number of iterations needed
    l1 = ['A cost value of ',num2str(cost)];
    l2 = ['has been gained after ', int2str(i_iter), ' iteration(s).'];   
    h1 = 'Success';
    msgbox ({l1, l2}, h1);
    
    % Release system
    feval (sys, [], [], [], 'term');
    
    % If a 5th output parameter is used
    if nargout > 4
      
      % Return errorflag as 5th parameter
      varargout(1) = {errflg};
      
    end
    
    % Game over
    return
    
  end
  
  % If the maximum number of iterations has been exceeded,
  % output error message and abort program
  if i_iter == n_iter

    l1 = ['Maximum number of iterations exceeded: ', int2str(i_iter)];   
    l2 = 'Program was aborted';   
    l3 = ['with a cost value of: ', num2str(cost)];
    h1 = 'Program aborted';
    errordlg ({l1; l2; l3}, h1);

    % Release system
    feval (sys, [], [], [], 'term');

    % Set errorflag
    errflg = 1;
    
    % If a 5th output parameter is used
    if nargout > 4
      
      % Return errorflag as 5th parameter
      varargout(1) = {errflg};
      
    end
    
    % Game over
    return
    
  end

  % If an improvement has been obtained
  % with respect to the last point,
  if cost < cost_old
    
    % accept and save this new point.
    % Important for a possible step size bisection later on
    x_u_old = x_u;
    
    % Save the cost value of this new point for a comparison later on
    cost_old = cost;    
    
    % Reset step size bisection counter
    i_bisec = 0;
    
    % Linearize relevant subsystem at current operating point
    jaco = jj_lin (sys, x_u, n_x, i_t_v, i_t_r, del_lin);
    
    % Singular Value Decomposition of the sensitivity matrix
    [u, s, v] = svd (jaco);
    
    % A singular value is assumed to be "zero", if it is 1e12 times smaller 
    % than the maximum singular value. Such a singular value indicates a rank deficiency.
    sv_min = s(1,1)*1e-12;
    
    % Find the indices of those "zero-singular-values"
    i_sv_zero = find (abs (diag (s)) <= sv_min);
    
    % If there are any zero-singular-values,
    if ~isempty (i_sv_zero) 
      
      % the jacobian matrix is singular.
      h1 = 'Singular Jacobian-Matrix';
      
      % Assemble cell arrays containing the names of all trim variables and trim requirements
      trim_variables = [x_nam; u_nam];
      trim_requirements = [d_nam; y_nam];
      
      % Loop over all zero-singular-values
      for i_sv = i_sv_zero'
        
        % Find those elements of the corresponding singular vectors that are not "zero"
        u_sing = find (abs (u(:,i_sv)) > sv_min);
        v_sing = find (abs (v(:,i_sv)) > sv_min);   
        
	      % Separating empty line
    	  l0 = {' '};

        % If there is only one non-zero element in the left singular vector,
        if length (u_sing) == 1
          
          % prepare the corresponding error message
          l1 = {'The trim requirement'};
          l2 = trim_requirements(i_t_r(u_sing));
          l3 = {'could not be affected by any trim variable.'};       
          
        % If there are more than one non-zero elements in the left singular vector
        else
          
          % prepare the corresponding error message
          l1 = {'The trim requirements'};
          l2 = trim_requirements(i_t_r(u_sing));
          l3 = {'linearly depend on each other.'};       
          
        end 
        
        % Separating empty line
        l4 = {' '};
        
        % If there is only one non-zero element in the right singular vector,
        if length (v_sing) == 1
          
          % prepare the corresponding error message
          l5 = {'The trim variable'};
          l6 = trim_variables(i_t_v(v_sing));
          l7 = {'does not affect any trim requirement.'};       
          
        % If there are more than one non-zero elements in the right singular vector
        else
          
          % prepare the corresponding error message
          l5 = {'The trim variables'};
          l6 = trim_variables(i_t_v(v_sing));
          l7 = {'linearly depend on each other.'};       
          
        end 
        
        l8 = {'Chose different trim variables and/or trim requirements.'};
        l9 = {'Or try different initial values.'};
        l10 = {'Or try to reduce step sizes.'};
        
        % Separating empty line
        l11 = {' '};
        
        l12 = {'The returned trim point is not valid.'};
        l13 = {'You can use the Untrim menu entry to return to the pre-trim state.'};
        
        % Output error message
        errordlg ([l0; l1; l2; l3; l4; l5; l6; l7; l4; l8; l9; l10; l11; l12; l13], h1);
        
      end
      
      % Release system
      feval (sys, [], [], [], 'term');
    
      % Set errorflag
      errflg = 1;
      
      % If a 5th output parameter is used
      if nargout > 4
        
        % Return errorflag as 5th parameter
        varargout(1) = {errflg};
        
      end
      
      % Game over
      return
      
    end
    
    % Assuming a linear system, the alteration of the trim variables 
    % necessary to compensate the trim requirements error can directly 
    % be calculated by the inversion of the linear subsystem model
    % (differential equations and output equations)
    del_t_v = jaco\del_t_r;
    
    % Calculate maximum ratio between allowed and necessary trim step size
    ratio_t_v = del_t_v ./ del_max(i_t_v);
    max_rat = max (abs (ratio_t_v));
    
    % If allowed step size has been exceeded,
    if max_rat > 1
      
      % scale all state and input step sizes, 
      % in order to exploit most of the allowed step size
      del_t_v = del_t_v/max_rat;
      
    end
    
    % If no improvement has been obtained
    % with respect to the last point,
  else
    
    % and if step size has not been bisected ten times before,
    if i_bisec < 10
      
      % bisect step size and change sign
      del_t_v = -del_t_v/2;
      
      % and increment bisection counter
      i_bisec = i_bisec + 1;
      
      % If step size has already been bisected ten times before,
    else
      
      % output error message and stop program
      l1 = 'Step size has been bisected ten times.';
      l2 = ['Program was aborted after ', int2str(i_iter), ' iteration(s)'];   
      l3 = ['with a cost value of ', num2str(cost), '.'];
      l4 = 'Try different initial values.'; 
      l5 = 'Or try to reduce step sizes.';
      h1 = 'Program aborted';
      errordlg ({l1; l2; l3; l4; l5}, h1);
      
      % Release system
      feval (sys, [], [], [], 'term');
    
      % Set errorflag
      errflg = 1;
      
      % If a 5th output parameter is used
      if nargout > 4
        
        % Return errorflag as 5th parameter
        varargout(1) = {errflg};
        
      end
      
      % Game over
      return
      
    end
    
  end
  
  % Calculate new trim point.
  % Always use old value *before* first bisection
  x_u(i_t_v) = x_u_old(i_t_v) + del_t_v;
  
  % Disassemble the generalized input vector
  x_tr = x_u(1:n_x);
  u_tr = x_u(n_x+1:end);
  
end

% Release system
feval (sys, [], [], [], 'term');