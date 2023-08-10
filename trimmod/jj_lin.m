function ...
  jaco = ...
  jj_lin (...
  sys, ...
  x_u, n_x, ...
  i_x_u, i_d_y, ...
  del_x_u)

%JJ_LIN   Subsystem linearisation of a nonlinear ordinary differential equation system 
% 
%   JACO = JJ_LIN (SYS, X_U, N_X, I_X_U, I_D_Y)  
%   linearizes the system with the name SYS at the operating point,
%   that is defined by the generalized input vector X_U.
%   N_X is the length of the original state vector X. 
%   It is needed for the dissassembling of the X_U vector 
%   in the parameter list of the system calls.
%   The matrix JACO only contains the subsystem defined by the 
%   index vectors I_X_U and I_D_Y.
%
%   JACO = JJ_LIN (SYS, X_U, N_X, I_X_U, I_D_Y, DEL_X_U)
%   additionally allows the specification of the perturbation levels 
%   DEL_X_U to be used for the gradient calculations.

%   Copyright 2000-2004, J. J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de


%   Version 1.2     26.05.2000


% If the user did not define the perturbation levels
if nargin < 6
  
  % Use default perturbation levels
  del_x_u = 1e-6*(1 + abs(x_u)); 
  
end

% Determine vector lengths
n_i_x_u = length (i_x_u);
n_i_d_y = length (i_d_y);

% Set time to zero explicitely (assume a time invariant system)
t = 0;

% Initialize matrices (will be constructed columnwise later on) 
jaco = [];

% Loop over all generalized inputs to be linearized.
% IMPORTANT: Vector has to be a row vector!
for i = i_x_u'
  
  % Save whole generalized input vector in x_u_left and x_u_right,
  % because we only want to waggle some specific generalized inputs 
  x_u_left  = x_u;
  x_u_right = x_u;
  
  % Waggle one generalized input
  x_u_left(i)  = x_u(i) - del_x_u(i);
  x_u_right(i) = x_u(i) + del_x_u(i);
  
  % Calculate outputs and derivatives at the current trim point.
  % Important: We have to calculate the outputs first!
  %            The derivatives would be wrong otherwise.
  % Unbelievable but true: Mathworks argues that this is not a bug but a feature!
  % And furthermore: Sometimes it is even necessary to do the output calculation twice
  % before you get the correct derivatives!
  % Mathworks says, they will take care of that problem in one of the next releases...
  y_left = feval (sys, t, x_u_left(1:n_x), x_u_left(n_x+1:end), 'outputs');
  y_left = feval (sys, t, x_u_left(1:n_x), x_u_left(n_x+1:end), 'outputs');
  d_left = feval (sys, t, x_u_left(1:n_x), x_u_left(n_x+1:end), 'derivs');
  
  y_right = feval (sys, t, x_u_right(1:n_x), x_u_right(n_x+1:end), 'outputs');
  y_right = feval (sys, t, x_u_right(1:n_x), x_u_right(n_x+1:end), 'outputs');
  d_right = feval (sys, t, x_u_right(1:n_x), x_u_right(n_x+1:end), 'derivs');
  
  % Assemble generalized output vectors
  d_y_left = [d_left; y_left];
  d_y_right = [d_right; y_right];
  
  % Generate one column of the jacobi-matrix for every generalized input to be linearized
  % and build up the matrix columnwise
  jaco_column = (d_y_right(i_d_y) - d_y_left(i_d_y))/(2*del_x_u(i));   
  jaco = [jaco, jaco_column]; 
  
end