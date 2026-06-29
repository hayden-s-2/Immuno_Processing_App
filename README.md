# Immuno_Processing_App
Code and other documents related to a streamlit app meant to assist in easy processing of immuno-stained histology images.

There will be two main peices of code pertaining to this project:
1) A python executable file which is used to run the streamlit app
2) An ImageJ FIJI macro file which can be run in ImageJ FIJI (V1.54p) - Should still work in newer versions assuming no major changes to core functionality

The streamlit app is planned to be hosted on the free streamlit community cloud, but this is a work in progress.

The ImageJ FIJI macro was created and tested on windows. It has been lightly tested on mac and should still work. The purpose of the macro is to take the raw, overlayed images of the immuno-stained tissues, rotate them to be horizontal, and crop them to the size of the tissue. It uses the main overlay image to find the desired rotation angle and crop size and then applies those to the separated channel images which are used for analysis. The macro does not always work perfectly depending on the quality of the image, but the same results can be achieved by hand - it can just be tedious and takes much longer.
