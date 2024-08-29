#!/bin/sh

#  sedapreprocess.sh
#  
#
#  Created by Tasci, Seda on 8/22/24.
#

# Initialize argument counter
argument_counter=0

# Loop through all provided arguments
for this_argument in "$@"
do
      ## Conditional assignments based on argument_counter
    if   [[ $argument_counter == 0 ]]; then
        Matlab_dir=$this_argument
    elif [[ $argument_counter == 1 ]]; then
        Template_dir=$this_argument
    elif [[ $argument_counter == 2 ]]; then
        Subject_dir=$this_argument
    elif [[ $argument_counter == 3 ]]; then
        License_dir=$this_argument
    elif [[ $argument_counter == 4 ]]; then
        TBSS_dir=$this_argument
    else
        preprocessing_steps[$((argument_counter-5))]="$this_argument" ## For arguments after the first four, use an array to store them
    fi
    (( argument_counter++ )) #increment counter;After processing each argument, argument_counter is incremented by 1 to move to the next argument in the next iteration of the loop.
done
    echo $preprocessing_steps

    export MATLABPATH=${Matlab_dir}/helper
    ml matlab/2020b
    ml gcc/5.2.0  # GNU Compiler Collection
    ml ants
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
 
    

for this_preprocessing_step in ${preprocessing_steps[@]}; do
    if [[ $this_preprocessing_step == "signal_denoise" ]]; then
        dwi_folder_name=($dwi_processed_folder_name)
        
        cd ${Subject_dir}/${dwi_folder_name}
        gunzip -qf *nii.gz
        
        #changed denoising to MRtrix 7/19/2024
        dwidenoise dwi.nii denoised_dwi.nii -force
        #correct for Gibbs ringing
        mrdegibbs denoised_dwi.nii denoised_unringed_dwi.nii -force
        
        echo "signal_denoise finished for $Subject_dir"
    fi
        
        
        #container gives topup results without using fieldmap
    if [[ $this_preprocessing_step == "container" ]]; then
           dwi_folder_name=($dwi_processed_folder_name)
           t1_folder_name=($t1_processed_folder_name)
     
        mkdir ${Subject_dir}/container
        container_folder_name=container

           cd ${Subject_dir}/${container_folder_name}
           mkdir ${Subject_dir}/${container_folder_name}/INPUTS
           mkdir ${Subject_dir}/${container_folder_name}/OUTPUTS
        
           
        #copy raw T1 from processed anat folder and denoised_unringed_dwi.nii from dwi processed folder to container INPUTS folder.
           cd ${Subject_dir}/${t1_folder_name}
           gzip t1.nii
           cp t1.nii.gz ${Subject_dir}/${container_folder_name}/INPUTS
        
           cd ${Subject_dir}/${dwi_folder_name}
           cp denoised_unringed_dwi.nii ${Subject_dir}/${container_folder_name}/INPUTS
           
    
        cd ${Subject_dir}/${container_folder_name}/INPUTS
        mv t1.nii.gz T1.nii.gz #change the name for container
        fslroi denoised_unringed_dwi.nii new_dwi.nii.gz 0 -1 0 -1 0 72 #remove last slice from denoised_unringed_dwi.nii
        cp new_dwi.nii.gz ${Subject_dir}/${dwi_folder_name} #prepare for steps after container
        fslroi new_dwi.nii.gz b0.nii.gz 0 1  #extract bo from new_dwi.nii.gz
           
        #copy license.txt(freesurfer text file for container) from License_dir and copy it to container folder.
           cd $License_dir
           cp license.txt ${Subject_dir}/${container_folder_name}
           
           
        #make acqparams.txt file in acq-64_dwi folder by using EP2D_DIFF_64DIR_0013_ep2d_diff_64DIR_20130908175018_13.json file and copy it to container INPUTS folder.
           cd ${Subject_dir}/dwi/acq-64_dwi
           
            #Loop through all JSON files (or specify the filename if needed)
            for this_json_file in *.json*; do

                #Extract the TotalReadoutTime and PhaseEncodingDirection
                total_readout=$(grep "TotalReadoutTime" ${this_json_file} | tr -dc '0.00-9.00')
                encoding_direction=$(grep "PhaseEncodingDirection" ${this_json_file} | cut -d: -f 2 | head -1 | tr -d '"' |  tr -d ',')

                #Determine encoding direction and write the first line to acqparams.txt
                if [[ $encoding_direction =~ j- ]]; then
                    echo 0 -1 0 ${total_readout} >> acqparams.txt
                else
                    echo 0 1 0 ${total_readout} >> acqparams.txt
                fi

                #Append the second line with a fixed value
                echo 0 -1 0 0.000000 >> acqparams.txt

            done
    
            cp acqparams.txt ${Subject_dir}/${container_folder_name}/INPUTS
            cp acqparams.txt ${Subject_dir}/${dwi_folder_name}
           
           cd ${Subject_dir}/${container_folder_name}
            
            singularity run -e \
            -B INPUTS/:/INPUTS \
            -B OUTPUTS/:/OUTPUTS \
            -B license.txt:/extra/freesurfer/license.txt \
            /blue/tpengzhao/tasciseda/synb0-disco_v3.1.sif
            
            echo "container finished for $Subject_dir"
        fi
        
        
        
        if [[ $this_preprocessing_step ==  "eddy_correction" ]]; then
           container_folder_name=container
           dwi_folder_name=($dwi_processed_folder_name)
            
            cd ${Subject_dir}/${container_folder_name}/OUTPUTS
            
            fslmaths b0_all_topup -Tmean b0_all_topup_mean
            bet b0_all_topup_mean b0_all_topup_brain -m
            gunzip -qf *.nii.gz
            
            cp b0_all_topup_brain_mask.nii ${Subject_dir}/${dwi_folder_name}
            cp topup_movpar.txt ${Subject_dir}/${dwi_folder_name}
            cp topup_fieldcoef.nii ${Subject_dir}/${dwi_folder_name}
            
            cd ${Subject_dir}/${dwi_folder_name}
            
            NVOL=`fslnvols new_dwi.nii`
            for ((i=1; i<=${NVOL}; i+=1)); do indx="$indx 1"; done; echo $indx > index.txt
            
            
            eddy --imain=new_dwi.nii --mask=b0_all_topup_brain_mask.nii --topup=topup --acqp=acqparams.txt --index=index.txt --bvecs=dwi.bvec --bvals=dwi.bval --niter=5 --fwhm=10,0,0,0,0 --repol --slm=linear --out=eddycorrected_denoised_unringed_dwi --estimate_move_by_susceptibility --cnr_maps --verbose
            

            #eddy_cuda9.1 --imain=new_dwi.nii \
            #--mask=b0_all_topup_brain_mask.nii \
            #--topup=topup \
            #--acqp=acqparams.txt \
            #--index=index.txt \
            #--bvecs=dwi.bvec \
            #--bvals=dwi.bval \
            #--niter=8 \
            #--fwhm=10,8,4,2,0,0,0,0 \
            #--repol \
            #--slm=linear \
            #--out=eddycorrected_denoised_unringed_dwi \
            #--mporder=16 \
            #--json=dwi.json \
            #--s2v_niter=8 \
            #--s2v_lambda=1 \
            #--s2v_interp=trilinear \
            #--estimate_move_by_susceptibility \
            #--cnr_maps \
            #--verbose
        
            echo "eddy done for $Subject_dir"
            gunzip -f *nii.gz
            
        fi
        
        if  [[ $this_preprocessing_step == "eddy_quad" ]]; then
            dwi_folder_name=($dwi_processed_folder_name)
  
            cd ${Subject_dir}/${dwi_folder_name}
            

            eddy_quad eddycorrected_denoised_unringed_dwi --eddyIdx index.txt --eddyParams acqparams.txt --mask b0_all_topup_brain_mask --bvals dwi.bval --bvecs eddycorrected_denoised_unringed_dwi.eddy_rotated_bvecs --output-dir=eddycorrected_denoised_unringed_dwi.qc
        
            gunzip -f *nii.gz
            echo "eddy quad done for $Subject_dir"
            
        fi
        
    done
            
           
           
           
           
           
           
