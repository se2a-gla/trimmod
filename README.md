# trimmod

This repository contains a copy from https://de.mathworks.com/matlabcentral/fileexchange/268-trimmod.

Please note the [license](license.txt).

TrimMod finds the trim point (equilibrium) of a Simulink system.
When invoked without left-hand arguments, TrimMod opens a new figure with a graphical user interface.
The user can load a Simulink system (.mdl), define certain trim point requirements and ask TrimMod to calculate the corresponding trim point variables that are necessary to satisfy the requirements.
This trim point is then automatically transferred to the 'Simulation; Model Configuration Parameters; Data Import/Export; Load from workspace' dialog box ('Input' and 'Initial state') of the corresponding Simulink system.  
Version 1.5 was tested under:  
MATLAB Version: 9 (R2016a), Microsoft Windows 10.

## Function Documentation

This project provides the following functions:  
- [jj_lin](https://htmlpreview.github.io/?https://github.com/se2a-gla/trimmod/blob/main/help/trimmod/jj_lin.html)  
- [jj_trim](https://htmlpreview.github.io/?https://github.com/se2a-gla/trimmod/blob/main/help/trimmod/jj_trim.html)  
- [trimmod](https://htmlpreview.github.io/?https://github.com/se2a-gla/trimmod/blob/main/help/trimmod/trimmod.html)  
