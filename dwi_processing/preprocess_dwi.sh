# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

argument_counter=0
for this_argument in "$@"
do
	if	[[ $argument_counter == 0 ]]; then
		Matlab_dir=$this_argument
	elif [[ $argument_counter == 1 ]]; then
		Template_dir=$this_argument
	elif [[ $argument_counter == 2 ]]; then
    	Subject_dir=$this_argument
	elif [[ $argument_counter == 3 ]]; then
		TBSS_dir=$this_argument
	else
		preprocessing_steps["$argument_counter-4"]="$this_argument"
	fi
	(( argument_counter++ ))
done
	echo $preprocessing_steps
	
	export MATLABPATH=${Matlab_dir}/helper
	ml matlab/2020b
	# module spider matlab
	ml gcc/5.2.0
	ml ants ## ml gcc/9.3.0; ml ants/2.3.4
	ml fsl/6.0.3
    ml mrtrix/3.0.3
	
	cd $Subject_dir
	pwd

	lines_to_ignore=$(awk '/#/{print NR}' file_settings.txt)

	dwi_line_numbers_in_file_info=$(awk '/dwi/{print NR}' file_settings.txt)
	t1_line_numbers_in_file_info=$(awk '/t1/{print NR}' file_settings.txt)

	dwi_line_numbers_to_process=$dwi_line_numbers_in_file_info
	t1_line_numbers_to_process=$t1_line_numbers_in_file_info

	this_index_dwi=0
	this_index_t1=0
	for item_to_ignore in ${lines_to_ignore[@]}; do
		for item_to_check in ${dwi_line_numbers_in_file_info[@]}; do
  			if [[ $item_to_check == $item_to_ignore ]]; then 
  				remove_this_item_fmri[$this_index_fmri]=$item_to_ignore
  				(( this_index_dwi++ ))
  			fi
  		done

  		for item_to_check in ${t1_line_numbers_to_process[@]}; do
  			if [[ $item_to_check == $item_to_ignore ]]; then 
  				remove_this_item_t1[$this_index_t1]=$item_to_ignore
  				(( this_index_t1++ ))
  			fi
  		done
	done

	for item_to_remove_fmri in ${remove_this_item_fmri[@]}; do
		dwi_line_numbers_to_process=$(echo ${dwi_line_numbers_to_process[@]/$item_to_remove_fmri})
	done

	for item_to_remove_t1 in ${remove_this_item_t1[@]}; do
		t1_line_numbers_to_process=$(echo ${t1_line_numbers_to_process[@]/$item_to_remove_t1})
	done

	this_index=0
	for this_line_number in ${dwi_line_numbers_to_process[@]}; do
		dwi_processed_folder_name_array[$this_index]=$(cat file_settings.txt | sed -n ${this_line_number}p | cut -d ',' -f2)
		(( this_index++ ))
	done
	

	this_index=0
	for this_line_number in ${t1_line_numbers_to_process[@]}; do
		t1_processed_folder_name_array[$this_index]=$(cat file_settings.txt | sed -n ${this_line_number}p | cut -d ',' -f2)
		(( this_index++ ))
	done
	
	dwi_processed_folder_name=$(echo "${dwi_processed_folder_name_array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
	t1_processed_folder_name=$(echo "${t1_processed_folder_name_array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
 
 

for this_preprocessing_step in ${preprocessing_steps[@]};do
	if [[ $this_preprocessing_step == "drift_correction" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
        
        cd ${Subject_dir}/${dwi_folder_name}
        gunzip -qf *nii.gz
		
        #changed denoising to MRtrix 7/19/2024
        dwidenoise dwi.nii denoised_dwi.nii -force
        #correct for Gibbs ringing
        mrdegibbs denoised_dwi.nii denoised_unringed_dwi.nii -force
        
        #gunzip DWI.nii.gz
        # ./create_bmat_text
        #matlab -nodesktop -nosplash -r "try; create_bmat_text; catch; end; quit"
		#matlab -nodesktop -nosplash -r "try; flip_or_permute; catch; end; quit"
		#matlab -nodesktop -nosplash -r "try; driftcorrect; catch; end; quit"
  
        #Flip PA added 3/28/2024 sumi
        #fieldmap_folder_name=($dwi_fieldmap_processed_folder_name)
        #cd ${Subject_dir}/${fieldmap_folder_name}
        #matlab -nodesktop -nosplash -r "try; flip_or_permute_PAFieldmaps; catch; end; quit"
	fi

   	if [[ $this_preprocessing_step == "fieldmap_dti" ]]; then
   		dwi_folder_name=($dwi_processed_folder_name)
     
        mkdir ${Subject_dir}/fieldmaps_dwi
        fieldmap_folder_name=fieldmaps_dwi

   		cd ${Subject_dir}/${fieldmap_folder_name}

        if [ -e distMap_AP1.nii ]; then
            rm distMap_AP1.nii
        fi
        if [ -e distMap_PA1.nii ]; then
            rm distMap_PA1.nii
        fi
        if [ -e distMap_AP2.nii ]; then
            rm distMap_AP2.nii
        fi
        if [ -e AP2_merged.nii ]; then
            rm AP2_merged.nii
        fi
        if [ -e AP_PA_merged.nii ]; then
            rm AP_PA_merged.nii
        fi
        if [ -e se_epi_unwarped.nii ]; then
            rm se_epi_unwarped.nii
        fi
        if [ -e se_epi_unwarped_brain_mask.nii ]; then
            rm se_epi_unwarped_brain_mask.nii
        fi
        if [ -e se_epi_unwarped_brain.nii ]; then
            rm se_epi_unwarped_brain.nii
        fi
        if [ -e se_epi_unwarped_mean.nii ]; then
            rm se_epi_unwarped_mean.nii
        fi
        if [ -e topup_results_fieldcoef.nii ]; then
            rm topup_results_fieldcoef.nii
        fi
        if [ -e topup_results_movpar.txt ]; then
            rm topup_results_movpar.txt
        fi
        if [ -e my_fieldmap_nifti.nii ]; then
            rm my_fieldmap_nifti.nii
        fi
        if [ -e acqParams.txt ]; then
            rm acqParams.txt
        fi
        if [ -e my_fieldmap_mask.nii ]; then
            rm my_fieldmap_mask.nii
            rm my_fieldmap_rads.nii
        fi
        
  
        fslroi ${Subject_dir}/${dwi_folder_name}/denoised_unringed_dwi.nii distMap_AP1.nii 0 1
        cp ${Subject_dir}/${dwi_folder_name}/dwi.json ${Subject_dir}/${fieldmap_folder_name}/distMap_AP1.json
        echo "extracted AP fieldmap $Subject_dir"


        fslroi ${Subject_dir}/dwi/acq-6_dwi/PROCESSED/dwi_acq6.nii.gz distMap_AP2.nii 0 1
        cp ${Subject_dir}/dwi/acq-6_dwi/PROCESSED/dwi_acq6.json ${Subject_dir}/${fieldmap_folder_name}/distMap_AP2.json
        echo "extracted AP fieldmap $Subject_dir"
        
        
        #Pecan dataset does not have PA maps
        #fslroi ${Subject_dir}/dwi_pa1/dwi_pa1.nii distMap_PA1.nii 0 1
        #cp ${Subject_dir}/dwi_pa1/dwi_pa1.json ${Subject_dir}/${fieldmap_folder_name}/distMap_PA.json
        #echo "extracted PA fieldmap $Subject_dir"
        

		#fslmerge -t AP_PA_merged.nii distMap_AP1.nii distMap_PA1.nii
        #echo "merged $Subject_dir"
        fslmerge -t AP2_merged.nii distMap_AP1.nii distMap_AP2.nii
        echo "merged $Subject_dir"
        
		gunzip -qf *nii.gz

		# just a dummy value to check whether ecoding direction is same between distmapss
		previous_encoding_direction=k
		# assuming only the DistMaps have .jsons in this folder
		for this_json_file in *.json*; do
								
			total_readout=$(grep "TotalReadoutTime" ${this_json_file} | tr -dc '0.00-9.00')
			encoding_direction=$(grep "PhaseEncodingDirection" ${this_json_file} | cut -d: -f 2 | head -1 | tr -d '"' |  tr -d ',')
            this_file_name=$(echo $this_json_file | cut -d. -f 1)
			
			#this_file_header_info=$(fslhd ${this_file_name}1.nii)
            this_file_header_info=$(fslhd ${this_file_name}.nii)
			this_file_number_of_volumes=$(echo $this_file_header_info | grep -o dim4.* | tr -s ' ' | cut -d ' ' -f 2)
            #make acquition parameters file
			for (( this_volume=1; this_volume<=$this_file_number_of_volumes; this_volume++ )); do
				if [[ $encoding_direction =~ j- ]]; then
					echo 0 -1 0 ${total_readout} >> acqParams.txt
				else
					echo 0 1 0 ${total_readout} >> acqParams.txt
				fi
			done
		done

		topup --imain=AP2_merged.nii --datain=acqParams.txt --fout=my_fieldmap --config=b02b0_1.cnf --iout=se_epi_unwarped --out=topup_results
		gunzip -qf *nii.gz
		fslmaths se_epi_unwarped -Tmean se_epi_unwarped_mean
		gunzip -qf *nii.gz
		bet se_epi_unwarped_mean se_epi_unwarped_brain -m
		gunzip -qf *nii.gz

		echo "topup finished for $Subject_dir"
   	fi

   	if [[ $this_preprocessing_step ==  "eddy_correction" ]]; then
        fieldmap_folder_name=fieldmaps_dwi
   		dwi_folder_name=($dwi_processed_folder_name)

   		cd ${Subject_dir}/${fieldmap_folder_name}
   		cp se_epi_unwarped_brain_mask.nii ${Subject_dir}/${dwi_folder_name}
		cp my_fieldmap.nii ${Subject_dir}/${dwi_folder_name}
		cp acqParams.txt ${Subject_dir}/${dwi_folder_name}
        cp topup_results* ${Subject_dir}/${dwi_folder_name}
        cd ${Subject_dir}/${dwi_folder_name}
        
		NVOL=`fslnvols denoised_unringed_dwi.nii`
		for ((i=1; i<=${NVOL}; i+=1)); do indx="$indx 1"; done; echo $indx > index.txt

        rm -r eddycorrected_denoised_unringed_dwi.qc
		rm eddycorrected_denoised_unringed_dwi.*
		

		eddy_cuda9.1 --imain=denoised_unringed_dwi.nii \
		--mask=se_epi_unwarped_brain_mask.nii \
		--topup=topup_results \
		--acqp=acqParams.txt \
		--index=index.txt \
		--bvecs=dwi.bvec \
		--bvals=dwi.bval \
		--niter=8 \
		--fwhm=10,8,4,2,0,0,0,0 \
		--repol \
		--slm=linear \
		--out=eddycorrected_denoised_unringed_dwi \
		--mporder=16 \
		--json=dwi.json \
		--s2v_niter=8 \
		--s2v_lambda=1 \
		--s2v_interp=trilinear \
		--estimate_move_by_susceptibility \
		--cnr_maps \
		--verbose
		
		echo "eddy done for $Subject_dir"
		gunzip -f *nii.gz
	fi

	if [[ $this_preprocessing_step ==  "eddy_correction_noFM" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
		t1_folder_name=($t1_processed_folder_name)

		# cp ${Subject_dir}/${t1_folder_name}/SkullStripped_biascorrected_T1.nii ${Subject_dir}/${dwi_folder_name}
		cd ${Subject_dir}/${dwi_folder_name}

		# rm acqParams.txt
		echo 0 -1 0 0.0355597 >> acqParams.txt
		# echo 0 1 0 0.0355597 >> acqParams.txt
		
		NVOL=`fslnvols denoised_unringed_dwi.nii`
		for ((i=1; i<=${NVOL}; i+=1)); do indx="$indx 1"; done; echo $indx > index.txt

		# rm eddycorrected_driftcorrected_DWI.*

		# flirt -in SkullStripped_biascorrected_T1.nii -ref driftcorrected_DWI.nii -out SkullStripped_biascorrected_T1_matched2DWI.nii
		# rm SkullStripped_biascorrected_T1_matched2DWI.nii
		# gunzip -f *nii.gz
		# fslmaths SkullStripped_biascorrected_T1.nii -bin se_epi_unwarped_brain_mask.nii
		rm se_epi_unwarped_brain_mask* 
		fslroi driftcorrected_DWI.nii driftcorrected_DWI1 0 1
		gunzip -f *nii.gz
		bet driftcorrected_DWI1.nii se_epi_unwarped_brain_mask -m
		gunzip -f *nii.gz

		# eddy_cuda9.1 --imain=driftcorrected_DWI.nii \
		# --mask=se_epi_unwarped_brain_mask.nii \
		# --index=index.txt \
		# --acqp=acqParams.txt \
		# --bvecs=DWI.bvec \
		# --bvals=DWI.bval \
		# --niter=8 \
		# --fwhm=10,8,4,2,0,0,0,0 \
		# --repol \
		# --slm=linear \
		# --out=eddycorrected_driftcorrected_DWI \
		# --mporder=16 \
		# --json=DWI.json \
		# --s2v_niter=8 \
		# --s2v_lambda=1 \
		# --s2v_interp=trilinear \
		# --estimate_move_by_susceptibility \
		# --cnr_maps \
		# --verbose
		
		eddy --imain=driftcorrected_DWI.nii \
		  --mask=se_epi_unwarped_brain_mask.nii \
		  --acqp=acqParams.txt \
		  --index=index.txt \
		  --bvecs=DWI.bvec \
		  --bvals=DWI.bval \
		  --repol \
		  --out=eddycorrected_driftcorrected_DWI \
		  --verbose

		gunzip -f *nii.gz
	fi
	
	if [[ $this_preprocessing_step == "eddy_quad" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
  
		cd ${Subject_dir}/${dwi_folder_name}

		rm -r eddycorrected_denoised_unringed_dwi.nii.qc
		
		eddy_quad ${Subject_dir}/${dwi_folder_name}/eddycorrected_denoised_unringed_dwi \
		--eddyIdx index.txt \
		--eddyParams acqParams.txt \
		--mask ${Subject_dir}/fieldmaps_dwi/se_epi_unwarped_brain_mask \
		--bvals dwi.bval \
		--bvecs eddycorrected_denoised_unringed_dwi.eddy_rotated_bvecs \
		--output-dir=eddycorrected_denoised_unringed_dwi.qc
		
		gunzip -f *nii.gz
		echo "eddy quad done for $Subject_dir"
	fi
	
	if [[ $this_preprocessing_step == "cleanup_dti" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
		cd ${Subject_dir}/${dwi_folder_name}
		gzip *.nii
	fi

	if [[ $this_preprocessing_step == "freewater_correction" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
        
		cd ${Subject_dir}/${dwi_folder_name}

		matlab -nodesktop -nosplash -r "try; run_FW_MSFreewater; catch; end; quit"
		echo "finished fw_dti processing ${Subject_dir}"
		gunzip *.nii.gz
	fi

	if [[ $this_preprocessing_step == "copy_fa_for_tbss" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
        
		cd ${Subject_dir}/${dwi_folder_name}
		gunzip *.gz
		if [[ ! -e ${TBSS_dir} ]]; then
			mkdir ${TBSS_dir}
		fi
		subjectid=$(echo ${Subject_dir} | egrep -o '[[:digit:]]{4}' | head -n1)
		if [[ -e eddycorrected_FA.nii ]]; then
			cp eddycorrected_FA.nii ${Subject_dir}/${dwi_folder_name}/${TBSS_dir}/${subjectid}_eddycorrected_FA.nii
		else
			echo "fa doesnt exist"
		fi
		echo "copying done"
	fi

	# if [[ $this_preprocessing_step == "invert_warps" ]]; then
	# 	dwi_folder_name=($dwi_processed_folder_name)
	# 	t1_folder_name=($t1_processed_folder_name)
	# 	cd $study_dir/TBSS_results/FW

	# 	# -mas se_epi_unwarped_brain_mask.nii
	# 	# consider only doing 
	# 	this_subject_id=$(echo $Subject_dir | cut -d "/" -f9)
	# 	echo $this_subject_id

	# 	invwarp --ref=target --warp=1002_tensorfit_eddycorrected_driftcorrected_DWI_FA_FA_to_target_warp --out=1002_tensorfit_eddycorrected_driftcorrected_DWI_FA_FA_to_target_warp_inv

	# 	# gunzip -f *nii.gz
	# fi

	if [[ $this_preprocessing_step == "view_tensors" ]]; then
		dwi_folder_name=($dwi_processed_folder_name)
		cd ${Subject_dir}/${dwi_folder_name}

		module load gui/2
		gui start --module fsl/6.0.3 -e fsleyes -c 2 -m 8 -t 24
	fi


done
