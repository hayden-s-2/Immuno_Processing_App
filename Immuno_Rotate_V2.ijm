macro "Rotate Immuno Images" {
	function deleteDirectory(dir) {
		del_list = getFileList(dir);
		for (i=0; i<del_list.length; i++) {
			File.delete(dir + del_list[i]);
		}
		File.delete(dir);
	}
	
	orig_dir = File.getDefaultDir;
	
	change_default_dir = getBoolean(
		"Would you like to change the default directory for easier "+
		"access to working files? This will only persist until FIJI is closed."
		);
		
	if (change_default_dir) {
		def_dir = getDir("Choose a new default directory");
		File.setDefaultDir(def_dir);
		print(def_dir);
	}
	
	main_dir = getDir("Choose Main Directory Containing the Image Folder");
	Dialog.create("Expected Files");
	Dialog.addMessage("After clicking OK on this message, you will be asked to select a folder containing your images.\nFor each tissue being processed, the folder is expected to contain one merged image of all the channels\nand a sub-folder with the same name containing an image for each of the separate channels.\nExample:\nImage -> B1171P_2H_CONTROL-T2_overlay.tif\nSub-Folder -> B1171P_2H_CONTROL-T2_overlay\nChannel Images -> B1171P_2H_CONTROL-T2_ch00.tif");
	Dialog.show();
	im_dir = getDir("Choose Folder Containing Images to be Processed");
	file_list = getFileList(im_dir);
	ims_in_dir = 0;
	
	for (i=0; i<file_list.length; i++) {
		if (endsWith(file_list[i], ".jpg")|endsWith(file_list[i], ".tif")) {
			ims_in_dir += 1;
		}
	}
	
	im_list = newArray(ims_in_dir);
	im_index = 0;
	for (i=0; i<file_list.length; i++) {
		if (endsWith(file_list[i], ".jpg")|endsWith(file_list[i], ".tif")) {
			im_list[im_index] = file_list[i];
			im_index += 1;
		}
		else {
			continue;
		}
	}

	print(im_list[0]);
	num_ims = lengthOf(im_list);
	
	temp_dir = im_dir + "temp_ims" + File.separator;
	if (!File.exists(temp_dir)) {
	    File.makeDirectory(temp_dir);
	}
	
	rot_dir = im_dir + "processed_imgs" + File.separator;
	if (!File.exists(rot_dir)) {
	    File.makeDirectory(rot_dir);
	}

	crop_xs = newArray(num_ims);
	crop_ys = newArray(num_ims);
	crop_Hs = newArray(num_ims);
	crop_Ws = newArray(num_ims);
	angles = newArray(num_ims);
	orig_names = newArray(num_ims);
	
	sub_dirs = newArray(num_ims);
	for (i=0; i<num_ims; i++) {
		main_im_name = im_list[i];
		file_name_split = split(main_im_name, ".");
		file_name_noex = file_name_split[0];
		sub_dirs[i] = im_dir+file_name_noex+File.separator;
	}
	
	// This assumes the scale bar is either in the top right or bottom left
	// Changed to handle any corner
	img_scales = File.open(im_dir+"Img_Scales.txt");
	
	for (im=0; im<num_ims; im++) {
		open(im_dir + im_list[im]);
		orig = getTitle();
		orig_names[im] = orig;
		
		setForegroundColor(0, 0, 0);
		
		run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
		
		run("Select None");
		
		setColor(0, 0, 0);
		floodFill(5, 0, "8-connected");
		floodFill(5, Image.height, "8-connected");
		floodFill(Image.width, 0, "8-connected");
		floodFill(Image.width, Image.height, "8-connected");
		
		corner1x = 0;
		corner1y = Image.height - 40;
		corner1w = 220;
		corner1h = 40;
		
		corner2x = Image.width - 220;
		corner2y = 0;
		corner2w = 220;
		corner2h = 40;
		
		corner3x = 0;
		corner3y = 0;
		corner3w = 220;
		corner3h = 40;
		
		corner4x = Image.width - 220;
		corner4y = Image.height - 40;
		corner4w = 220;
		corner4h = 40;
		
		fillRect(corner1x, corner1y, corner1w, corner1h);
		fillRect(corner2x, corner2y, corner2w, corner2h);
		fillRect(corner3x, corner3y, corner3w, corner3h);
		fillRect(corner4x, corner4y, corner4w, corner4h);
		
		origW = getWidth();
		origH = getHeight();
		origDiag = Math.sqrt(pow(origW, 2) + pow(origH, 2));
		run("Canvas Size...", "width=origDiag height=origDiag");
		floodFill(5, 5, "8-connected");
//		floodFill((Image.width-5), 5, "8-connected");
		diagW = getWidth();
		diagH = getHeight();
		
		run("Duplicate...", "title=thresh");
		
		selectWindow(orig);
		file_name_split = split(orig, ".");
		file_name_noex = file_name_split[0];
		file_ex_dot = replace(orig, file_name_noex, "");
		new_file_name = file_name_noex+"_temp"+file_ex_dot;
		save(temp_dir + File.separator + new_file_name);
		close(orig);
		
		newW = diagW*0.25;
		newH = diagH*0.25;
		run("Select None");
		run("Size...", "width=newW height=newH average=true interpolation=Bilinear");
		
		run("8-bit");
		run("Auto Threshold", "method=MinError(I) ignore_black white");
		setThreshold(128, 255);
		run("Convert to Mask");
		run("Fill Holes");
		
		run("Set Measurements...", "fit redirect=None decimal=3");
		run("Analyze Particles...", "size=1000-Infinity pixel display clear");
		print(nResults());
		el_major = 0;
		final_i = 0;
		i = 0;
		while (i < nResults()) {
			if ((88 < getResult("Angle", i))&&(getResult("Angle", i) < 92)) {
				i += 1;
			}
//			if (getResult("Minor", i) > (Image.height/3))
//				i += 1
			else if (getResult("Major", i) > el_major) {
				el_major = getResult("Major", i);
				final_i = i;
				i += 1;
			}
			else {
				i += 1;
			}
		}
		angle = getResult("Angle", final_i);
		print(angle);
		angle_fixed = (-1)*(180 - angle);
		angles[im] = angle_fixed;
		print(angle_fixed);
		run("Rotate...", "angle="+(angle_fixed)+" grid=1 interpolation=Bilinear");
		
		run("Convert to Mask");
		run("Set Measurements...", "bounding redirect=None decimal=3");
		run("Analyze Particles...", "size=5000-Infinity pixel display clear");
		
		j = 0;
		final_j = 0;
		area_sum = 0;
		height = 0;
		width = 0;
		while (j < nResults()) {
			if ((getResult("BX", j)==0)|((getResult("BY", j)+getResult("Height", j))==Image.height))
				j += 1;
			else if ((getResult("Width", j))+(getResult("Height", j)) > area_sum) {
				area_sum = (getResult("Width", j))+(getResult("Height", j));
				width = getResult("Width", j);
				height = getResult("Height", j);
				final_j = j;
				j += 1;
			}
			else {
				j += 1;
			}
		}
		
		BX = getResult("BX", final_j);
		BY = getResult("BY", final_j);
		cropBX = (BX*4) - 50;
		crop_xs[im] = cropBX;
		cropBY = (BY*4) - 50;
		crop_ys[im] = cropBY;
		cropW = (width*4) + 100;
		crop_Ws[im] = cropW;
		cropH = (height*4) + 100;
		crop_Hs[im] = cropH;
		
		close("*");
	}
	
	Array.getStatistics(crop_Hs, min, max, mean, stdDev);
	max_H = max;
	print(max_H);
	
	temp_ims_in_dir = 0;
	temp_file_list = getFileList(temp_dir);
	for (i=0; i<temp_file_list.length; i++) {
		if (endsWith(temp_file_list[i], ".jpg")|endsWith(temp_file_list[i], ".tif")) {
			temp_ims_in_dir += 1;
		}
	}
	
	temp_im_list = newArray(temp_ims_in_dir);
	temp_im_index = 0;
	for (i=0; i<temp_file_list.length; i++) {
		if (endsWith(temp_file_list[i], ".jpg")|endsWith(temp_file_list[i], ".tif")) {
			temp_im_list[temp_im_index] = temp_file_list[i];
			temp_im_index += 1;
		}
		else {
			continue;
		}
	}
	
	print(temp_im_list[0]);
	num_ims = lengthOf(temp_im_list);
	
	for (im=0; im<num_ims; im++) {
		for (H=0; H<num_ims; H++) {
			if (crop_Hs[H] < max_H) {
				H_diff = max_H - crop_Hs[H];
				half_diff = H_diff / 2;
				old_y = crop_ys[H];
				new_y = old_y - half_diff;
				crop_ys[H] = new_y;
				old_H = crop_Hs[H];
				new_H = old_H + H_diff;
				crop_Hs[H] = new_H;
			}
			else {
				continue;
			}
		}
		
		open(temp_dir + File.separator + temp_im_list[im]);
		temp = getTitle();
		run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
		
		run("Rotate...", "angle="+(angles[im])+" grid=1 interpolation=Bilinear");
		makeRectangle(crop_xs[im], crop_ys[im], crop_Ws[im], crop_Hs[im]);
		run("Crop");
		
		newIM = getTitle();
		origH = Image.height;
		origW = Image.width;
		
		orig = orig_names[im];
		file_name_split = split(orig, ".");
		file_name_noex = file_name_split[0];
		file_ex_dot = replace(orig, file_name_noex, "");
		new_file_name = file_name_noex+"_rotated"+file_ex_dot;
		save(rot_dir + File.separator + new_file_name);
		close("*");
	}
	
	im_dir_orig = im_dir;
	im_dir = rot_dir;
	print(im_dir);
	im_list = getFileList(im_dir);
	num_ims = lengthOf(im_list);
	binary_flip = newArray(num_ims);
	
	for (i=0; i<num_ims; i++) {
		open(im_dir + im_list[i]);
		binary_flip[i] = getBoolean("Flip Image?");
	}
	
	for (i=0; i<num_ims; i++) {
		if (binary_flip[i]) {
			selectWindow(im_list[i]);
			run("Rotate...", "angle=180 grid=1 interpolation=Bilinear");
			angles[i] += 180;
			save(im_dir + im_list[i]);
		}
	}
	close("*");
	run("Collect Garbage");
	run("Collect Garbage");
	
	for (i=0; i<lengthOf(sub_dirs); i++) {
		sub_dir_ims = getFileList(sub_dirs[i]);
		num_sub_dir_ims = lengthOf(sub_dir_ims);
		for (j=0; j<num_sub_dir_ims; j++) {
			open(sub_dirs[i]+sub_dir_ims[j]);
			
			setForegroundColor(0, 0, 0);
			run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
			
			run("Select None");
			
			origW = getWidth();
			origH = getHeight();
			origDiag = Math.sqrt(pow(origW, 2) + pow(origH, 2));
			run("Canvas Size...", "width=origDiag height=origDiag");
			floodFill(5, 5, "8-connected");
			run("Rotate...", "angle="+(angles[i])+" grid=1 interpolation=Bilinear");
			makeRectangle(crop_xs[i], crop_ys[i], crop_Ws[i], crop_Hs[i]);
			run("Crop");
			save(sub_dirs[i]+sub_dir_ims[j]);
			close("*");
		}
	}
	
	deleteDirectory(temp_dir);
	File.setDefaultDir(orig_dir);
	exit("Saved new images");
}
