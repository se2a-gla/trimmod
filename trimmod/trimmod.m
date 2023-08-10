function varargout = trimmod (action, varargin)

%TRIMMOD   Find the trim point of a Simulink system
%
%   TRIMMOD
%   finds the trim point (equilibrium) of a Simulink system. 
%   When invoked without left-hand arguments, 
%   trimmod opens a new figure with a graphical user interface. 
%   The user can load a Simulink system (.mdl or .slx), 
%   define certain trim point requirements and 
%   ask trimmod to calculate the corresponding trim point variables 
%   that are necessary to satisfy the requirements. 
%   This trim point is then automatically transferred to the 
%   "Simulation Parameters Workspace I/O" dialog box 
%   ("Load Input from Workspace" and "Load Initial States") 
%   of the corresponding Simulink system.
% 
%   H = TRIMMOD
%   When invoked with a left-hand argument, H = TRIMMOD
%   opens the gui and additionally returns the handle H of the figure.

%   Copyright J. J. Buchholz, Hochschule Bremen, buchholz@hs-bremen.de


%   Version 1.5     07.11.2011
%
%   Array initialization warning suppressed.
%   Minor code optimizations.


%   Version 1.4     15.08.2002
%
%   Model file name and path can now be mixed upper and lower case,
%   which might be necessary on UNIX systems.
%
%   trimmod 1.4 works with jj_trim 1.2 and jj_lin 1.2.


%   Version 1.3     31.01.2001
%
%   Setfield-syntax has changed from Matlab 5.3 to 6.0:
%   e.g.       (new): a = setfield (a, 'b', 'c', 'entry')
%   instead of (old): a = setfield (a, 'b.c', 'entry') 
%
%   Figures now have a .fig type. The former .m and .mat combination of figures
%   is not used anymore.
%
%   Figures (and included objects) can now be resized.
%
%   trimmod 1.3 works with jj_trim 1.2 and jj_lin 1.2.


%   Version 1.2     26.05.2000
%
%   The names of inputs, ... outputs for the error messages 
%   are now transferred via the parameter list.
%
%   The precompilation and the release of the system is now done in jj_trim.


% Action taken depends on the number of input arguments.
% A user usually calls trimmod without input arguments;
% TrimMod calls itself recursively with varying input arguments.
switch nargin
  
  
%  I N I T I A L I Z A T I O N  
  
% If the number of input arguments is zero
case 0
  
  % Display the graphical user interface and save its handle
  fig_han = openfig ('trimmod');
  
  % If trimmod has been invoked with a left-hand argument,
  if nargout > 0
    
    % return the handle of the gui
    varargout{1} = fig_han;
    
  end
  
  % Extract handles and strings of all tooltips and save them in the userdata property
  % of the tooltip menu switch.
  % This is necessary only once during the initialization phase and might be used later
  % if the tooltips are switched off and on again.
  
  % Find the handle of the "Show Tooltips" menu entry
  tooltip_menu_handle = findobj (gcf, 'type', 'uimenu', 'tag', 'show_tooltips');
  
  % Find all uicontrols in the current figure  
  all_ui_controls = findall (gcf, 'type','uicontrol');
  
  % Find all uicontrols that have *no* tooltip.
  % Necessary, because it is not (yet) possible in Matlab to find all uicontrols 
  % that have a tooltip in one step
  no_tooltip_handles = findall (all_ui_controls, 'flat', 'tooltipstring', '');
  
  % Find and save all uicontrols that *have* a tooltip.
  tooltip.handles = all_ui_controls(~ismember (all_ui_controls, no_tooltip_handles));
  
  % Save the tooltip strings
  tooltip.strings = get (tooltip.handles, 'tooltipstring');
  
  % Save tooltip handles and tooltip strings in the userdata property
  % of the tooltip menu switch
  set (tooltip_menu_handle, 'userdata', tooltip);
  
  % Create a new figure for the parameters and save the handle of that figure
  parameters_handle = openfig ('parameters');
  
  % Make the figure invisible.
  set (parameters_handle, 'visible', 'off');

  % Initialize the userdata property of the edit texts
  set (findobj (parameters_handle, 'style', 'edit', 'tag', 'max_iterations'), ...
    'userdata', 42);
  set (findobj (parameters_handle, 'style', 'edit', 'tag', 'cost_value'), ...
    'userdata', 1e-9);
  
    
% N O R M A L   O P E R A T I O N
  
% If the number of input arguments is one or two 
case {1 , 2}
  
  % Initialization of normal operation.
  % Variables defined here can be used in every callback case
  
  % Define a cell array holding the names of all frames.
  % Will be used by more than one callback case
  frames = {'input', 'derivative', 'state', 'output'};
    
  % Define a cell array holding the names of all edit texts.
  % Will be used by more than one callback case
  edits = {'_value', '_trim', '_lin'};
    
  % Always read the userdata property of the current figure first
  fud = get (gcbf, 'userdata');
  
  
  % Start of the switch grave.
  % The first callback argument defines the action to be taken
  switch action
    
    
  % If the menu entry "Open Model" has been selected  
  case 'open_model'
    
    % Open a file select box and save the selection
    [file_name, file_path] = uigetfile ('*.slx;*.mdl', 'Open Model');
    
    % If the user has pressed the cancel button,
    if ~file_name
      
      % do nothing at all
      return
      
    end
    
    % Extract the model name (without the file extension) 
    % and save it in the figure user data structure
    fud.model_name = strtok (file_name, '.');
    
    % Extract the model path and save it without the trailing backslash
    fud.model_path = file_path (1:(end - 1));
    
    % Insert the model name in the heading of the gui
    set (gcbf, 'name', ['Trim Model ', fud.model_name]);
    
    % Set the working directory to the model path
    cd (fud.model_path);
    
    % Open the main system blockdiagram internally
    % This dummy evaluation opens the main system internally,
    % without bringing the main system blockdiagram to front
    [~, ~, ~] = eval (fud.model_name);
    
    % Supress the array initialization warning
    set_param (fud.model_name, 'InitInArrayFormatMsg', 'None');

    % Call model and save model parameters.
    % Since Release 11 (Version 5.3) the state names vector does include the newline characters.
    [sizes, initial_conditions, state_names_with_nl] = eval (fud.model_name);    
    
    % Save number of states, inputs and outputs in figure user data
    fud.n_states = sizes (1);
    fud.n_outputs = sizes (3);
    fud.n_inputs = sizes (4);
  
    set (gcbf, 'userdata', fud);
    
    % Find the block types of all states.
    % Valid types are 'Integrator', 'StateSpace', 'TransferFcn', 'ZeroPole', and 'S-Function'
    state_types = get_param (state_names_with_nl, 'blocktype'); 
    
    % Save the state names cell array (with newline characters) in the userdata property
    % of the state and derivative listboxes of the gui
    set (findobj (gcbf, 'style', 'listbox', 'tag', 'state'), 'userdata', state_names_with_nl);
    set (findobj (gcbf, 'style', 'listbox', 'tag', 'derivative'), 'userdata', state_names_with_nl);
    
    % Save the state types in the userdata property of the corresponding gui objects
    set (findobj (gcbf, 'style', 'text', 'tag', 'state'), 'userdata', state_types);
    set (findobj (gcbf, 'style', 'text', 'tag', 'derivative'), 'userdata', state_types);
    
    % Substitute the newline characters in the state names by blanks for better readability
    state_names = kill_nl (state_names_with_nl);
    
    % Loop over all the states
    for i_state = 1 : fud.n_states
      
      % Strip the model name from the state names
      % in order to make the names easier to read in the listbox
      state_names{i_state} = state_names{i_state}(length (fud.model_name) + 2 : end);
      
    end
    
    % Uniquefy(?) multiple state names 
    
    % Loop over all the states
    for i_state = 1 : fud.n_states
      
      % Find multiple state names and number of multiple state names
      matches = find (strcmp (state_names(i_state), state_names));
      n_matches = length (matches);
      
      % If multiple state names have been found
      if n_matches > 1
        
        % S-Functions have to be treated differently:
        % They can return a list (cell array) of their internal state names,
        % if the user has defined the "str"-output argument 
        % of the initialization (zero-flag) call:
        % [dummy, dummy, str, dummy] = s_function_name ([], [], [], 0)
        % An example can be found in the function "mdlInitializeSizes" 
        % in the file "second_order.m".
        
        % If the state belongs to an S-Function
        if strcmp (state_types{i_state}, 'S-Function')
          
          % Find the block of that state
          block_name = state_names_with_nl(i_state);
          
          % Get the name of the S-Function that is called by that block
          function_name = get_param (block_name, 'FunctionName');
          
          % Get the state names of that S-Function
          [~, ~, s_function_state_names, ~] = ...
            feval (function_name{1}, [], [], [], 0);
          
          % If the user has defined the S-Function state names as a string cell array
          if ~isempty (s_function_state_names) 
          
            % Loop over all copies of a multiple state name
            for i_match = 1 : n_matches
            
              % Append the internal S-Function state name to every copy of a multiple state name
              state_names{matches(i_match)} = ...
                [state_names{matches(i_match)}, ' ', s_function_state_names{i_match}];
            
            end
            
          end
          
        % If the state does not belong to an S-Function  
        else
          
          % Loop over all copies of a multiple state name
          for i_match = 1 : n_matches
            
            % Append "___1"," ___2", ... to every copy of a multiple state name
            state_names{matches(i_match)} = ...
              [state_names{matches(i_match)}, '___', num2str(i_match)];
            
          end
          
        end
        
      end
      
      % Derivatives get the words "Deriv. of" in front of their names
      % to make sure the user understands that these are the derivatives of the states
      derivative_names{i_state} = ['Deriv. of ', state_names{i_state}]; 
      
    end
    
    % Save the modified state names in the string property
    % of the state and derivative listboxes of the gui
    set (findobj (gcbf, 'style', 'listbox', 'tag', 'state'), 'String', state_names);
    set (findobj (gcbf, 'style', 'listbox', 'tag', 'derivative'), 'String', derivative_names);
    
    % Save the initial conditions of the block diagram integrators 
    % in the userdata property of the state edit text 
    set (findobj (gcbf, 'style', 'edit', 'tag', 'state_value'), 'userdata', ...
      initial_conditions);
    
    % Initialize all the other edit texts with zeros
    set (findobj (gcbf, 'style', 'edit', 'tag', 'input_value'), 'userdata', ...
      zeros (fud.n_inputs, 1));
    set (findobj (gcbf, 'style', 'edit', 'tag', 'input_trim'), 'userdata', ...
      zeros (fud.n_inputs, 1));
    set (findobj (gcbf, 'style', 'edit', 'tag', 'input_lin'), 'userdata', ...
      zeros (fud.n_inputs, 1));
    set (findobj (gcbf, 'style', 'edit', 'tag', 'state_trim'), 'userdata', ...
      zeros (fud.n_states, 1));
    set (findobj (gcbf, 'style', 'edit', 'tag', 'state_lin'), 'userdata', ...
      zeros (fud.n_states, 1));
    set (findobj (gcbf, 'style', 'edit', 'tag', 'derivative_value'), 'userdata', ...
      zeros (fud.n_states, 1));
    set (findobj (gcbf, 'style', 'edit', 'tag', 'output_value'), 'userdata', ...
      zeros (fud.n_outputs, 1));
    
    % Initialize all checkboxes to "not checked"
    set (findobj (gcbf, 'style', 'checkbox', 'tag', 'state'), 'userdata', ...
      zeros (fud.n_states, 1));
    set (findobj (gcbf, 'style', 'checkbox', 'tag', 'input'), 'userdata', ...
      zeros (fud.n_inputs, 1));
    set (findobj (gcbf, 'style', 'checkbox', 'tag', 'derivative'), 'userdata', ...
      zeros (fud.n_states, 1));
    set (findobj (gcbf, 'style', 'checkbox', 'tag', 'output'), 'userdata', ...
      zeros (fud.n_outputs, 1));
    
    % Define a cell array holding the two strings "In" and "Out"
    % and an array holding the numbers of inputs and outputs
    in_out = {'In'; 'Out'};
    n_in_out = [fud.n_inputs; fud.n_outputs];
    
    % Repeat twice (once for the inputs and once for the outputs)
    for i_num = 1 : 2
      
      % Select the correct substring ("In" or "Out")
      in_out_str = in_out{i_num};
      
      % Concatenate the corresponding port ("Inport" or "Outport")
      port_str = [in_out_str, 'port'];
      
      % Concatenate the corresponding inputs/outputs ("Input" or "Output")
      put_str = [lower(in_out_str), 'put'];
      
      % Find all ports (even in libraries: 'FollowLinks')
      port_names = find_system (fud.model_name, 'FollowLinks', 'on', 'searchdepth', 1, 'Blocktype', port_str);
      
      % Save port names in the userdata property of the corresponding listbox
      set (findobj (gcbf, 'style', 'listbox', 'tag', put_str), 'UserData', port_names);
      
      % Save the number of ports
      n_ports = length (port_names);
      
      % Loop over all ports
      for i_port = 1 : n_ports
        
        % Strip the model name from the port names
        % in order to make the names easier to read in the listbox
        port_names{i_port} = port_names{i_port}(length (fud.model_name) + 2 : end);
        
      end
      
      % If there are more inputs/outputs than ports, some of the ports are vector ports.
      if n_ports < n_in_out(i_num)
        
        % Display a warning
        l1 = ['TrimMod cannot determine the widths of vector ', port_str, 's.'];
        l2 = ['In this case TrimMod uses generic ', port_str, ' names:'];
        l3 = ['Single element of vector ', port_str, '___1'];
        l4 = ['Single element of vector ', port_str, '___2'];
        l5 = '...';
        l6 = ['Use scalar ', port_str, 's if you want to see their specific names.'];
        box_title = ['Vector ', port_str, '(s)'];
        warndlg ({l1; l2; l3; l4; l5; l6}, box_title);
        
        % Loop over all inputs/outputs
        for i_put = 1 : n_in_out(i_num)
          
          % Forget the original names and consecutively number the ports
          port_names{i_put} = ...
            ['Single element of vector ', port_str, '___', num2str(i_put)];
          
        end
        
        % Save the portnames in the user data property of the corresponding listbox
        set (findobj (gcbf, 'style', 'listbox', 'tag', put_str), 'UserData', port_names);
        
      end
      
      % Remove the newline characters and
      % save the portnames in the user string property of the corresponding listbox
      set (findobj (gcbf, 'style', 'listbox', 'tag', put_str), 'String', kill_nl (port_names));
      
    end      
    
    % Loop over all frames
    for i_frame = frames
      
      % Reset current listbox value.
      % Otherwise there were a problem, if the current listbox value of the old model 
      % was greater than the number of the listbox items in the new model
      set (findobj (gcbf, 'style', 'listbox', 'tag', i_frame{1}), 'value', 1);
      
    end
    
    % Update all edit, checkbox, and text fields
    trimmod ('update');
    
    % Enable all menu entries,
    set (findobj (gcbf, 'type', 'uimenu'), 'enable', 'on');
    
    % except the "Untrim" menu entry
    set (findobj (gcbf, 'type', 'uimenu', 'tag', 'untrim'), 'enable', 'off');
    
    % Append model name to menu entry "Save Trim Point in ..."
    set (findobj (gcbf, 'type', 'uimenu', 'tag', 'save_trim_point'), ...
      'label', ['&Save Trim Point in ', fud.model_name, '.mat']);
    
    % Enable all listboxes, edit texts, checkboxes, and pushbuttons;
    set (findobj (gcbf, 'style', 'listbox'), 'enable', 'on');
    set (findobj (gcbf, 'style', 'edit'), 'enable', 'on');
    set (findobj (gcbf, 'style', 'checkbox'), 'enable', 'on');
    set (findobj (gcbf, 'style', 'pushbutton'), 'enable', 'on');
    
  % If the menu entry "Save Trim Point" has been selected  
  case 'save_trim_point'
    
    % Save model name in save structure
    save_struct = struct ('model_name', fud.model_name);
    
    % Loop over all frames (in order to save all listboxes, checkboxes, and edit texts)
    for i_frame = frames
      
      % Get all the listbox strings
      string_data = get (findobj (gcbf, 'style', 'listbox', 'tag', i_frame{1}), 'string');      
      
      % Append listbox strings into new field of save structure
      save_struct = setfield (save_struct, 'listbox', i_frame{1}, string_data);      
      
      % Get all checkbox userdata properties
      userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', i_frame{1}), 'userdata');      
        
      % Append checkbox userdata into new field of save structure
      save_struct = setfield (save_struct, 'checkbox', i_frame{1}, userdata);      
        
      % Loop over all (three) edit texts
      for i_edit = edits
      
        % Construct the tag name of the edit text (e.g. "input_value", "input_trim", ...)
        tag_name = [i_frame{1}, i_edit{1}];
        
        % Get the currrent edit text (with all its elements)
        userdata = get (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'userdata');
    
        % Some combinations are not valid (e.g. "derivative_trim", ...)
        if ~isempty (userdata)  

          % Append edit text userdata into new field of save structure
          save_struct = setfield (save_struct, 'edit', tag_name, userdata);      
      
        end      
        
      end
      
    end
    
    % If trimmod has been called with the input argument 'save_trim_point' only,
    if nargin == 1
      
      % assemble the file name, into which the trim point will be saved,
      % directly from the model name
      file_name = [fud.model_name, '.mat'];
      
    % If trimmod has been called with an additional input argument,
    else
      
      % take this additional input argument as the file name
      file_name = varargin{1};
      
    end
    
    % Save the save structure 
    save (file_name, 'save_struct');
    
    
  % If the menu entry "Save Trim Point As" has been selected  
  case 'save_trim_point_as'
    
    % Open a file select box and let the user decide where to save the trim point
    [file_name, file_path] = uiputfile ([fud.model_name, '.mat'], 'Save Trim Point');
    
    % If the user has pressed the cancel button,
    if ~file_name
      
      % do nothing at all
      return
      
    end
    
    % Recursively call TrimMod with the file name as the second input argument
    trimmod ('save_trim_point', [file_path, file_name]);
    
    
  % If the menu entry "Load Trim Point" has been selected  
  case 'load_trim_point'
    
    % Open a file select box and let the user decide which trim point to load
    [file_name, file_path] = uigetfile ('*.mat', 'Load Trim Point');
    
    % If the user has pressed the cancel button,
    if ~file_name
      
      % do nothing at all
      return
      
    end
    
    % Load new trim point
    load ([file_path, file_name]);
    
    % Loop over all frames
    for i_frame = frames
      
      % Extract the listbox strings from the preloaded trim point
      listbox_string_save = save_struct.listbox.(i_frame{1});
      
      % Get the listbox strings from the current model
      listbox_string = ...
        get (findobj (gcbf, 'style', 'listbox', 'tag', i_frame{1}), 'string');
      
      % Find those strings that are identical in the preloaded trim point listbox
      % and in the current model listbox.
      % Only these trim point definitions will be updated
      [~, rows_save, rows] = intersect (listbox_string_save, listbox_string);
      
      % Extract the checkbox strings from the preloaded trim point
      checkbox_userdata_save = save_struct.checkbox.(i_frame{1});
      
      % Get the checkbox strings from the current model
      checkbox_userdata = ...
        get (findobj (gcbf, 'style', 'checkbox', 'tag', i_frame{1}), 'userdata');
      
      % Copy relevant checkbox trim point definitions from preloaded trim point to buffer,
      checkbox_userdata(rows) = checkbox_userdata_save(rows_save);
      
      % and update current model with buffer
      set (findobj (gcbf, 'style', 'checkbox', 'tag', i_frame{1}), ...
        'userdata', checkbox_userdata);
      
      % Loop over all (three) edit texts
      for i_edit = edits
      
        % Construct the tag name of the edit text (e.g. "input_value", "input_trim", ...)
        tag_name = [i_frame{1}, i_edit{1}];
      
        % Get the edit text strings from the current model
        edit_userdata = ...
          get (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'userdata');
      
        % Some combinations are not valid (e.g. "derivative_trim", ...)
        if ~isempty (edit_userdata)  
        
          % Extract the edit text strings from the preloaded trim point
          edit_userdata_save = save_struct.edit.(tag_name);
      
          % Copy relevant edit text trim point definitions from preloaded trim point to buffer,
          edit_userdata(rows) = edit_userdata_save(rows_save);
      
          % and update current model with buffer
          set (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'userdata', edit_userdata);
          
        end
        
      end
      
    end
    
    % Update all edit, checkbox, and text fields
    trimmod ('update');
    
    
  % If the menu entry "Exit TrimMod" has been selected  
  case 'exit_trimmod'
    
    % Ask user if (s)he wants to save the trim point
    button = questdlg ('Save trim point before closing?', ...
      'Save trim point', ...
      'Yes', 'No', 'Cancel', 'Yes');
    
    % Action taken depends on button pressed
    switch button   
      
    % If the "yes"-button has been pressed,  
    case 'Yes'
      
      % recursively call TrimMod with the "save_trim_point_as" action flag
      trimmod save_trim_point_as; 
      
      % Close the gui (the current call back figure)
      delete (gcbf);   
      
      % Find the handle of the "Additional Parameters" figure
      parameters_handle = findobj ('tag', 'parameters');
    
      % Close the "Additional Parameters" figure
      delete (parameters_handle);   

      
    % If the "No"-button has been pressed,  
    case 'No'    
      
      % simply close the gui (the current call back figure)
      delete (gcbf);   
      
      % Find the handle of the "Additional Parameters" figure
      parameters_handle = findobj ('tag', 'parameters');
    
      % Close the "Additional Parameters" figure
      delete (parameters_handle);   

      
    % If the "Cancel"-button has been pressed,  
    case 'Cancel'    
      
      % do nothing at all
      return;   
      
    end
    
    
  % If the "Show Blockdiagram"-button in the gui has been pressed
  case 'blockdiagram'
    
    % Find out in which frame the button has been pressed
    tag_name = get (gcbo, 'tag');
    
    % Get all the names from the current listbox
    listbox_names = get (findobj (gcbf, 'style', 'listbox', 'tag', tag_name), 'userdata');
    
    % Get the value of the current element of the listbox
    listbox_value = get (findobj (gcbf, 'style', 'listbox', 'tag', tag_name), 'value');
    
    % Find the name of the current element of the listbox
    block_to_open = listbox_names{listbox_value};
    
    % If the current element is part of a vector input or output,
    if strncmp ('Single element of vector ', block_to_open, 25)
      
      % the corresponding block cannot be found.
      % Only the main system blockdiagram is opened
      open_system (fud.model_name);
      
    % If the current element is *not* part of a vector input or output,
    else
      
      % Find the indices of all slashes in the name of the blockdiagram to be opened
      slashes = strfind (block_to_open, '/');
      
      % Find the index of the last slash
      last_slash = slashes (end);
      
      % The system to be opened is the whole path to the block to be opened 
      % up to the last slash
      system_to_open = block_to_open(1 : last_slash - 1);
      
      % Open blockdiagram of current listbox element
      open_system (system_to_open);
      
      % Save the background color of the current block
      old_backgroundcolor = get_param (block_to_open, 'backgroundcolor');
      
      % Blink three times
      for i_blink = 1 : 3
         
        % Cycle between red and white 
        for i_color = {'red', 'white'}
           
          % Switch color 
					set_param (block_to_open, 'backgroundcolor', i_color{1})
         
        	% Wait half a second
        	pause (0.5)
        
        end
        
   	  end   
      
      % Restore the original background color
      set_param (block_to_open, 'backgroundcolor', old_backgroundcolor)
      
    end
    
    
  % If the current listbox element has changed
  case 'list' 
    
    % Get the listbox frame name
    tag_name = get (gcbo, 'tag');
    
    % Update frame
    trimmod ('update', tag_name);
    
    
  % If a checkbox has been checked
  case 'checkbox'
    
    % Get the checkbox frame name
    tag_name = get (gcbo, 'tag');
    
    % Get the value of the current listbox element in the current frame
    listbox_value = get (findobj (gcbf, 'style', 'listbox', 'tag', tag_name), 'value');
    
    % Get the value of the current checkbox (i.e. the state of the checkbox)
    checkbox_value = get (findobj (gcbf, 'style', 'checkbox', 'tag', tag_name), 'value');
    
    % Get the userdata of the current checkbox
    % (i.e. the states of all the elements in the current frame)
    checkbox_userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', tag_name), 'userdata');
    
    % Update the state of the current checkbox
    checkbox_userdata(listbox_value) = checkbox_value;
    
    % Save the updated checkbox state in the userdata property of the current checkbox
    set (findobj (gcbf, 'style', 'checkbox', 'tag', tag_name), 'userdata', checkbox_userdata);
    
    % Update frame
    trimmod ('update', tag_name);
    
    
  % If an edit text has been changed  
  case 'edit'
    
    % Get the edit text tag name
    tag_name = get (gcbo, 'tag');
    
    % The first part of the tag name is the frame name ("input", "state", ...)
    frame_name = tag_name(1:strfind(tag_name, '_')-1);
    
    % Get the value of the current listbox element in the current frame
    listbox_value = get (findobj (gcbf, 'style', 'listbox', 'tag', frame_name), 'value');
    
    % Get the string of the current edit text (i.e. the current user input)
    edit_string = get (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'string');
    
    % Get the userdata of the current edit text
    % (i.e. all the numbers behind the edit text strings in the current frame)
    edit_userdata = get (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'userdata');
    
    % Try to convert the current edit string to a number
    edit_num = str2double (edit_string);
    
    % If the edit string is not a scalar number, 
    if isnan (edit_num) 
      
      % inform the user about the error,
      errordlg ([edit_string, ' is not a number']);
      
      % change the color of the edit string to red (as a warning),
      set (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'foregroundcolor', [1 0 0]);
      
      % disable the current listbox (as a warning), and
      set (findobj (gcbf, 'style', 'listbox', 'tag', frame_name), 'enable', 'off');
      
      % disable the trim menu entry
      set (findobj (gcbf, 'type', 'uimenu', 'tag', 'trim'), 'enable', 'off')
        
      
    % If the edit string is a scalar number,
    else
      
      % (re)set the color of the edit string back to black,
      set (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'foregroundcolor', [0 0 0]);
      
      % (re)enable the current listbox,
      set (findobj (gcbf, 'style', 'listbox', 'tag', frame_name), 'enable', 'on');
      
      % (re)enable the trim menu entry,
      set (findobj (gcbf, 'type', 'uimenu', 'tag', 'trim'), 'enable', 'on')
      
      % update the current edit text value, and
      edit_userdata(listbox_value) = edit_num;
      
      % save the updated edit text in the userdata property of the current edit text
      set (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'userdata', edit_userdata);
      
    end
    
    
  % If the menu entry "Overview" has been selected  
  case 'overview'
    
    % Create a new figure for the overview and save the handle of that figure
    overview_handle = openfig ('overview');
    
    % The overview figure is modal, i.e. it has to be closed before the program continues
    set (overview_handle, 'WindowStyle', 'modal');
    
    % Find the handle of the listbox in the overview figure
    listbox_handle = findobj (overview_handle, 'style', 'listbox');
    
    % Create an empty cell array
    listbox_string = cell (0);
    
    % Wieland wanted a special order of the variable frames.
    % Trim variables first; then the trim requirements
    overview_frames = {'input', 'state', 'derivative', 'output'};
    
    % Recall the pre-trim structure from the userdata property of the "Untrim" menu entry
    pre_trim = get (findobj (gcbf, 'type', 'uimenu', 'tag', 'untrim'), 'userdata');
    
    % Loop over all frames
    for i_frame = overview_frames
      
      % Get the string of the current listbox element (the names of the variables)
      frame_listbox_string = ...
      get (findobj (gcbf, 'style', 'listbox', 'tag', i_frame{1}), 'string');
    
      % Get the userdata of the current "value" edit text element
      frame_value_data = ...
      get (findobj (gcbf, 'style', 'edit', 'tag', [i_frame{1},'_value']), 'userdata');
    
      % Get the userdata of the current "trim" edit text element
      frame_trim_data = ...
      get (findobj (gcbf, 'style', 'edit', 'tag', [i_frame{1},'_trim']), 'userdata');
    
      % Get the userdata of the current "lin" edit text element
      frame_lin_data = ...
      get (findobj (gcbf, 'style', 'edit', 'tag', [i_frame{1},'_lin']), 'userdata');
    
      % Get the userdata of the current checkbox element (the states of the variables)
      frame_checkbox_data = ...
      get (findobj (gcbf, 'style', 'checkbox', 'tag', i_frame{1}), 'userdata');
    
      % If the pre-trim structure has not been initialized,
      if ~isstruct (pre_trim)
        
        % copy the current data (new) to the pre-trim vector (old)
        pre_trim_data = frame_value_data;
        
      % If the pre-trim structure has been initialized,
      else
        
        % extract the current pre-trim vector from the pre-trim structure
        pre_trim_data = pre_trim.(i_frame{1});
        
      end
      
      % If the model has been modified, 
      if length (frame_value_data) ~= length (pre_trim_data)
        
        % update the pre-trim vector 
        pre_trim_data = frame_value_data;
        
      end  
      
      % Loop over all variables in the current listbox
      for i_string = 1 : length (frame_listbox_string)
        
        % Fill the frame buffer with the pre- and post-trim values 
        % and the name of the current element
        frame_listbox_string {i_string} = ...
          [sprintf('%15.6e', pre_trim_data(i_string)), ...
          sprintf('%15.6e', frame_value_data(i_string)), ...
          ' ', frame_listbox_string{i_string}];
            
        % If the frame is "input" or "state",
        if ((strcmp ('input', i_frame)) || (strcmp ('state', i_frame)))
          
          % add the "trim" and "lin" data to the frame buffer
          frame_listbox_string {i_string} = ...    
          [sprintf('%15.6e', frame_trim_data(i_string)), ...
          sprintf('%15.6e', frame_lin_data(i_string)), ...
          frame_listbox_string{i_string}];
          
        end
        
        % If the current element is a trim variable or a trim requirement,
        if frame_checkbox_data(i_string)
          
          % and if the current element is a trim variable,
          if ((strcmp ('input', i_frame)) || (strcmp ('state', i_frame)))
            
            % fill the frame buffer with a "TV" in the first column 
            frame_listbox_string {i_string} = ['TV', frame_listbox_string{i_string}];
            
          % If the current element is a trim requirement,
          else
            
            % fill the frame buffer with a "TR" in the first column 
            frame_listbox_string {i_string} = ['TR', frame_listbox_string{i_string}];
            
          end
          
        % If the current element is neither a trim variable nor a trim requirement,
        else
          
          % leave the first column blank
          frame_listbox_string {i_string} = ['  ', frame_listbox_string{i_string}];
          
        end
      
      end
        
      % Add some separation lines to the overview buffer
      listbox_string = [listbox_string; {''}];
      listbox_string = [listbox_string; {'******************************************'}];
      
      % Move the frame name a bit to the right
      frame_name = ['               ', upper(i_frame{1})];
      
      % Add the current frame name to the overview buffer
      listbox_string = [listbox_string; {frame_name}];
      
      % Add a separation line to the overview buffer
      listbox_string = [listbox_string; {'******************************************'}];
      
      % If the frame is "input" or "state",
      if ((strcmp ('input', i_frame)) || (strcmp ('state', i_frame)))
        
        % add the long heading to the overview buffer
        listbox_string = [listbox_string; ...
          {'      MAX. TRIM      LIN. STEP      PRE-TRIM       POST-TRIM     NAME'}];
            
      % If the frame is "derivative" or "output",
      else
        
        % add the short heading to the overview buffer
        listbox_string = [listbox_string; {'      PRE-TRIM       POST-TRIM     NAME'}];
          
      end
        
      % Add the frame buffer to the overview buffer
      listbox_string = [listbox_string; frame_listbox_string];
      
    end
    
    % Display the overview buffer
    set (listbox_handle, 'string', listbox_string);
      
    
  % If the menu entry "Trim" has been selected  
  case 'trim'
    
    % Copy states, inputs, ... to variables x, u, ...
    x = get (findobj (gcbf, 'style', 'edit', 'tag', 'state_value'), 'userdata');
    u = get (findobj (gcbf, 'style', 'edit', 'tag', 'input_value'), 'userdata');
    d = get (findobj (gcbf, 'style', 'edit', 'tag', 'derivative_value'), 'userdata');
    y = get (findobj (gcbf, 'style', 'edit', 'tag', 'output_value'), 'userdata');
    
    % Find the indices of all trim variables and trim requirements
    i_x = find (get (findobj (gcbf, 'style', 'checkbox', 'tag', 'state'), 'userdata'));
    i_u = find (get (findobj (gcbf, 'style', 'checkbox', 'tag', 'input'), 'userdata'));
    i_d = find (get (findobj (gcbf, 'style', 'checkbox', 'tag', 'derivative'), 'userdata'));
    i_y = find (get (findobj (gcbf, 'style', 'checkbox', 'tag', 'output'), 'userdata'));
    
    % Find the names of inputs, states, derivatives and outputs 
    x_nam =  get (findobj (gcbf, 'style', 'listbox', 'tag', 'state'), 'string');
    u_nam =  get (findobj (gcbf, 'style', 'listbox', 'tag', 'input'), 'string');
    d_nam =  get (findobj (gcbf, 'style', 'listbox', 'tag', 'derivative'), 'string');
    y_nam =  get (findobj (gcbf, 'style', 'listbox', 'tag', 'output'), 'string');
    
    % Find the handle of the "Additional Parameters" figure
    parameters_handle = findobj ('tag', 'parameters');
    
    % Fill the options vector with the corresponding values 
    % from the "Additional Parameters" figure
    options(1) = get (findobj ...
      (parameters_handle, 'style', 'edit', 'tag', 'max_iterations'), 'userdata');
    options(2) = get (findobj ...
      (parameters_handle, 'style', 'edit', 'tag', 'cost_value'), 'userdata');
    
    % Get the current values for "Max. Trim Step" and "Linear Step"
    del_x_max = get (findobj (gcbf, 'style', 'edit', 'tag', 'state_trim'), 'userdata');
    del_u_max = get (findobj (gcbf, 'style', 'edit', 'tag', 'input_trim'), 'userdata');
    del_x_lin = get (findobj (gcbf, 'style', 'edit', 'tag', 'state_lin'), 'userdata');
    del_u_lin = get (findobj (gcbf, 'style', 'edit', 'tag', 'input_lin'), 'userdata');
  
    % Replace every zero-element in "Max. Trim Step" with the default value (1e42)
    del_x_max(~del_x_max) = 1e42;
    del_u_max(~del_u_max) = 1e42;
  
    % Replace every zero-element in "Linear Step" with the default value (1e-6*(1+abs(...)))
    del_x_lin(~del_x_lin) = 1e-6*(1 + abs(x(~del_x_lin)));
    del_u_lin(~del_u_lin) = 1e-6*(1 + abs(u(~del_u_lin)));
  
    % Enable the "Untrim" menu entry
    set (findobj (gcbf, 'type', 'uimenu', 'tag', 'untrim'), 'enable', 'on');
    
    % Save the "old" (pre-trim) variables in a structure
    pre_trim.state = x;
    pre_trim.input = u;
    pre_trim.derivative = d;
    pre_trim.output = y;
    
    % Save the pre-trim structure in the userdata property of the "Untrim" menu entry
    set (findobj (gcbf, 'type', 'uimenu', 'tag', 'untrim'), 'userdata', pre_trim);
    
    % Call the actual trim algorithm
    [x_tr, u_tr, d_tr, y_tr] = jj_trim ( ...
			fud.model_name, ...
      x, u, d, y, ...
      i_x, i_u, i_d, i_y, ...
      x_nam, u_nam, d_nam, y_nam, ...
      del_x_max, del_u_max, del_x_lin, del_u_lin, ...
      options);

    % Save the trim vectors in the userdata properties of the edit texts  
    set (findobj (gcbf, 'style', 'edit', 'tag', 'state_value'), 'userdata', x_tr);
    set (findobj (gcbf, 'style', 'edit', 'tag', 'input_value'), 'userdata', u_tr);
    set (findobj (gcbf, 'style', 'edit', 'tag', 'derivative_value'), 'userdata', d_tr);
    set (findobj (gcbf, 'style', 'edit', 'tag', 'output_value'), 'userdata', y_tr);
    
    % Update all frames
    trimmod ('update');
    
    % Convert the state trim vector to a string, with maximum precision
    % A postulated precision of 42 seems to give more significant(?) digits
    % than the recommended version without any postulated precision
    x_tr_string = mat2str (x_tr, 42);
    
    % Convert the input trim vector to a string
    % Add a zero as the "time span"
    u_tr_string = mat2str ([0, u_tr'], 42);
    
    % Check (Enable) the "Load Initial States" checkbox 
    % in the "Simulation Parameters" menu entry of the current model
    set_param (fud.model_name, 'LoadInitialState', 'on');
    
    % Transfer the state trim vector to the "Load Initial States" edit text 
    % in the "Simulation Parameters" menu entry of the current model.
    % This seems to be the only way to automatically set the trim point
    % in the current model
    set_param (fud.model_name, 'InitialState', x_tr_string);
    
    % Check (Enable) the "Load Input from Workspace" checkbox 
    % in the "Simulation Parameters" menu entry of the current model
    set_param (fud.model_name, 'LoadExternalInput', 'on');
    
    % Transfer the input trim vector to the "Load Input from Workspace" edit text 
    % in the "Simulation Parameters" menu entry of the current model.
    set_param (fud.model_name, 'ExternalInput', u_tr_string);
    
    
  % If the menu entry "Untrim" has been selected  
  case 'untrim'
     
    % Disable the "Untrim" menu entry.
    % Only one untrim is possible.
    set (findobj (gcbf, 'type', 'uimenu', 'tag', 'untrim'), 'enable', 'off');

    % Recall the pre-trim structure from the userdata property of the "Untrim" menu entry
    pre_trim = get (findobj (gcbf, 'type', 'uimenu', 'tag', 'untrim'), 'userdata');
        
    % Loop over all frames
    for i_frame = frames
  
      % Extract the pre-trim vector from the pre-trim structure
      field_value = pre_trim.(i_frame{1});
      
      % Save the pre-trim vector in the userdata property of the edit text.
      set (findobj (gcbf, 'style', 'edit', 'tag', [i_frame{1},'_value']), 'userdata', field_value);
  
    end
    
    % Update all frames
    trimmod ('update');
  
  
  % If the menu entry "Show Tooltips" has been selected  
  case 'show_tooltips'
    
    % Find the handle of the "Show Tooltips" menu entry
    tooltip_menu_handle = findobj (gcbf, 'type', 'uimenu', 'tag', 'show_tooltips');
    
    % Get all the tooltips
    tooltip = get (tooltip_menu_handle, 'userdata');
    
    % Get the state of the "Show Tooltips" menu entry
    checked = get (tooltip_menu_handle, 'checked');
    
    % If the "Show Tooltips" menu entry is checked,
    if strcmp (checked, 'on')
      
      % toggle the check state to "off" and
      checked = 'off';
      
      % clear all tooltips 
      set (tooltip.handles, 'tooltipstring', '');
      
    % If the "Show Tooltips" menu entry is not checked,
    else
      
      % toggle the check state to "on" and
      checked = 'on';
      
      % reset all tooltips to their default values
      set (tooltip.handles, {'tooltipstring'}, tooltip.strings);
      
    end
    
    % Update the visible checkstate in the menu entry
    set (findobj (gcbf, 'type', 'uimenu', 'tag', 'show_tooltips'), 'checked', checked);
    
    
  % If the menu entry "Additional Parameters" has been selected  
  case 'additional_parameters'
  
    % Find the handle of the "Additional Parameters" figure
    parameters_handle = findobj ('tag', 'parameters');
    
    % make it visible
    set (parameters_handle, 'visible', 'on');
  
  
  % If an edit text in the "Additional Parameters" figure has been changed  
  case 'parameter_edit'
    
    % Get the edit text tag name
    %tag_name = get (gcbo, 'tag');
    
    % Get the string of the current edit text (i.e. the current user input)
    edit_string = get (gcbo, 'string');
    
    % Try to convert the current edit string to a number
    edit_num = str2double (edit_string);
    
    % If the edit string is not a scalar number, 
    if isnan (edit_num)
      
      % inform the user about the error,
      errordlg ([edit_string, ' is not a number']);
      
      % change the color of the edit string to red (as a warning),
      set (gcbo, 'foregroundcolor', [1 0 0]);
      
      % and disable the OK button
      set (findobj (gcbf, 'style', 'pushbutton'), 'enable', 'off');
  
    % If the edit string is a scalar number,
    else
      
      % (re)set the color of the edit string back to black,
      set (gcbo, 'foregroundcolor', [0 0 0]);
      
      % (re)enable the OK button,
      set (findobj (gcbf, 'style', 'pushbutton'), 'enable', 'on');
  
      % and save the updated edit text in the userdata property of the current edit text
      set (gcbo, 'userdata', edit_num);
  
    end
    
    
  % If the OK button of the "Additional Parameters" figure has been pushed 
  case 'exit_parameters'  
     
    % Make the figure invisible.
    % Do not close the figure, because the data would be lost.
  set (gcbf, 'visible', 'off')
  
    
  % If the menu entry "About TrimMod" has been selected  
  case 'about_trimmod'
    
    % Display the standard "About" dialog
    helpdlg ({'TrimMod'; ...
        'Release 1.5'; ...
        'Joerg J. Buchholz'; ...
        'Hochschule Bremen'; ...
        'Germany'; ...
        'buchholz@hs-bremen.de'}, ...
        'About TrimMod');
    
    
  % If the menu entry "Help on Trim Point" has been selected  
  case 'help_on_trimmod'
    
    % Call the default browser and display the HTML help text (trimmod.html)
    % This only works if trimmod.html has been copied to
    % ...\MATLAB\help\toolbox\trimmod\trimmod.html
    doc trimmod/trimmod    
    
    
  % If TrimMod is supposed to update one or more frames
  case 'update'
    
    % If "update" has been called without an extra argument,
    if nargin == 1
      
      % all frames have to be updated
      update_frames = frames;
      
    % If "update" has been called with an extra argument,
    else
      
      % the extra argument is taken as the only frame to be updated
      update_frames = varargin(1);
      
    end
    
    % Loop over all frames 
    % (could also be only one frame)
    for i_frame = update_frames
      
      % Get the value of the current listbox element in the current frame
      listbox_value = get (findobj (gcbf, 'style', 'listbox', 'tag', i_frame{1}), 'value');
      
      % If the current frame is a state frame or a derivative frame,
      if strcmp (i_frame{1}, 'state') || strcmp (i_frame{1}, 'derivative')
        
        % get all the state types and
        text_userdata = get (findobj (gcbf, 'style', 'text', 'tag', i_frame{1}), 'userdata');
        
        % update the corresponding state type text
        set (findobj (gcbf, 'style', 'text', 'tag', i_frame{1}), ...
          'string', text_userdata{listbox_value});
        
      end 
      
      % Loop over all (three) edit texts
      for i_edit = edits
      
        % Construct the tag name of the edit text (e.g. "input_value", "input_trim", ...)
        tag_name = [i_frame{1}, i_edit{1}];
      
        % Get the currrent edit text (with all its elements)
        edit_userdata = get (findobj (gcbf, 'style', 'edit', 'tag', tag_name), 'userdata');
    
        % Some combinations are not valid (e.g. "derivative_trim", ...)
        if ~isempty (edit_userdata)  

          % Update the current edit text
          set (findobj (gcbf, 'style', 'edit', 'tag', tag_name), ...
            'string', edit_userdata(listbox_value));
      
        end      
      
      end
      
      % Get all checkbox states
      checkbox_userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', i_frame{1}), 'userdata');
      
      % Update the current checkbox
      set (findobj (gcbf, 'style', 'checkbox', 'tag', i_frame{1}), ...
        'value', checkbox_userdata(listbox_value));
      
    end
    
    % Check if the number of trim varibales equals the number of trim requirements
    
    % Get the userdata of all checkboxes (the checked items)
    input_userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', 'input'), 'userdata');
    derivative_userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', 'derivative'), 'userdata');
    state_userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', 'state'), 'userdata');
    output_userdata = get (findobj (gcbf, 'style', 'checkbox', 'tag', 'output'), 'userdata');
    
    % Calculate the number of trim variables and trim requirements
    n_trim_variables = sum (input_userdata) + sum (state_userdata);
    n_trim_requirements = sum (derivative_userdata) + sum (output_userdata);
    
    % Write these numbers on the screen
    set (findobj (gcbf, 'style', 'text', 'tag', 'number of trim variables'), ...
      'string', n_trim_variables);
    set (findobj (gcbf, 'style', 'text', 'tag', 'number of trim requirements'), ...
      'string', n_trim_requirements);
    
    % If the number of of trim variables equals the number of trim requirements,
    if n_trim_variables == n_trim_requirements
      
      % write this information on the screen (in green)
      set (findobj (gcbf, 'style', 'text', 'tag', 'relation'), ...
        'string', 'equals', ...
        'foregroundcolor', [0 1 0]);
      
      % and enable the "Trim" menu entry
      set (findobj (gcbf, 'type', 'uimenu', 'tag', 'trim'), 'enable', 'on')
      
    % If the number of of trim variables does not equal the number of trim requirements,
    else
      
      % write this information on the screen (in red)
      set (findobj (gcbf, 'style', 'text', 'tag', 'relation'), ...
        'string', 'does not equal', ...
        'foregroundcolor', [1 0 0]);
      
      % and disable the "Trim" menu entry
      set (findobj (gcbf, 'type', 'uimenu', 'tag', 'trim'), 'enable', 'off')
      
    end
    
  % If TrimMod has been called with an unknown type of argument,
  otherwise
    
    % write an error message on the screen
    error (['Unknown type of callback argument: ', action]);
    
  end
  
% If TrimMod has been called with more than 2 input arguments
otherwise
  
  % write an error message on the screen
  error (['Invalid number of input arguments: ', int2str(nargin)]); 
  
end