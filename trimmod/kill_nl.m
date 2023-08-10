function with_blank = kill_nl (with_nl)

%KILL_NL   Substitute newline characters with blanks
%
%   WITH_BLANK = KILL_NL (WITH_NL)
%   The input argument WITH_NL can be a string array or a cell array
%   containing newline characters ("carriage return" and "line feed").
%   These line terminaters are replaced with blanks in the output
%   argument WITH_BLANK.

%   Copyright 2000-2004, J. J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de

%   Version 1.2     26.05.2000


% If the input argument is a string array,
if ischar (with_nl)
  
  % find all "carriage returns" (ASCII 10) and "line feeds" (ASCII 13)
  % and replace them with blanks
  with_nl(with_nl == char (10)) = ' ';  
  with_nl(with_nl == char (13)) = ' ';  
  with_blank = with_nl;
  
% If the input argument is a (two-dimensional) cell array (of strings),
elseif iscellstr (with_nl)
  
  % find the number of rows and columns
  [rows, columns] = size (with_nl);
  
  % Loop over all rows
  for i_row = 1 : rows
    
    % Loop over all columns
    for i_column = 1 : columns
      
      % Extract one cell array element
      one_string = with_nl{i_row, i_column};      
  
      % find all "carriage returns" (ASCII 10) and "line feeds" (ASCII 13)
      % and replace them with blanks
      one_string(one_string == char (10)) = ' ';  
      one_string(one_string == char (13)) = ' ';  
      with_blank{i_row, i_column} = one_string;
      
    end
    
  end
  
% If the input argument is neither a string array, 
% nor a (two-dimensional) cell array (of strings),
else
  
  % display an error message
  error ('Input argument has to be a string array or a cell array of strings')
  
end
