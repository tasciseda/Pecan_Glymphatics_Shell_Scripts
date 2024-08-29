#!/bin/sh

#  dtialps_proc.sh
#  
#
#  Created by Sumire Sato on 4/9/24.
#  
argument_counter=0
for this_argument in "$@"
do
    if  [[ $argument_counter == 0 ]]; then
        Matlab_dir=$this_argument
    elif [[ $argument_counter == 1 ]]; then
        Template_dir=$this_argument
    elif [[ $argument_counter == 2 ]]; then
        Subject_dir=$this_argument
    else
        preprocessing_steps["$argument_counter-3"]="$this_argument"
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
dwi_folder_name=($dwi_processed_folder_name)

T1_Template=SkullStripped_biascorrected_T1.nii
this_T1_core_file_name=SkullStripped_biascorrected_T1

DWI_file=eddycorrected_denoised_unringed_dwi.nii
this_core_file_name=$(echo $DWI_file | cut -d. -f 1)
ROIfolder=/blue/tpengzhao/SHARED/ROI/DTIALPS

    
    
for this_preprocessing_step in ${preprocessing_steps[@]}; do
    if [[ $this_preprocessing_step == "copyfiles_ants" ]]; then
        
        cd ${Subject_dir}/${dwi_folder_name}
        
        mkdir -p ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization
        echo "making new directory for ANTS"
        
       this_t1_folder=($t1_processed_folder_name)
        
       echo "copy files for ANTS"
        cp ${Subject_dir}/${this_t1_folder}/${T1_Template} ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization
        cp ${DWI_file} ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization
        cp se_epi_unwarped_brain_mask.nii ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization
        
    fi
        
    if [[ $this_preprocessing_step == "coreg_dwi" ]]; then
        cd ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization
        
        echo "extract b0 volume for coregistration"
        #extract b0
        fslroi eddycorrected_denoised_unringed_dwi eddycorrected_denoised_unringed_dwi_b0 0 1
        
        DWIb0_file=eddycorrected_denoised_unringed_dwi_b0.nii.gz
        this_b0_file_name=$(echo $DWIb0_file | cut -d. -f 1)
        
        echo 'registering' $DWI_file 'to' $T1_Template

        #moving low res func to high res T1
        antsRegistration --dimensionality 3 --float 0 \
        --output [warpToT1Params_${this_b0_file_name},warpToT1Estimate_${this_b0_file_name}.nii] \
        --interpolation Linear \
        --winsorize-image-intensities [0.005,0.995] \
        --use-histogram-matching 0 \
        --initial-moving-transform [$T1_Template,$DWIb0_file,1] \
        --transform Rigid[0.1] \
        --metric MI[$T1_Template,$DWIb0_file,1,32,Regular,0.25] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox
        
        #Resample Skull-stripped, bias-corrected T1(Original resolution is 0.8 mm) to DWI resolution (2mm).
        #If I don't do this, when transforms are applied, DWI images will be upsampled to the same resolution as T1. This causes the coregistered T1 to be 10GB in size (1GB zipped)
        #resample_image is a function from ANTs
        echo "resample T1 to 2mm resolution"
        resample_image -d 2,2,2 ${this_T1_core_file_name}.nii downsample_${this_T1_core_file_name}.nii.gz
        
        echo "co-registration DWI to T1"
        #apply transforms
        antsApplyTransforms -d 3 -e 3 \
        -i ${this_core_file_name}.nii \
        -r downsample_${this_T1_core_file_name}.nii.gz \
        -n BSpline \
        -o warpedToT1_eddycorrected_denoised_unringed_dwi.nii.gz \
        -t [warpToT1Params_${this_b0_file_name}0GenericAffine.mat,0] -v

        echo "co-registration brain mask to T1"
        #apply transforms to mask (needed for DTIFIT)
        antsApplyTransforms -d 3 \
        -i se_epi_unwarped_brain_mask.nii \
        -r downsample_${this_T1_core_file_name}.nii.gz \
        -n GenericLabel \
        -o warpedToT1_se_epi_unwarped_brain_mask.nii.gz \
        -t [warpToT1Params_${this_b0_file_name}0GenericAffine.mat,0] -v
        
    fi
        
    if [[ $this_preprocessing_step == "normalize_dwi" ]]; then
        
        MNI_Template=${Template_dir}/MNI_1mm.nii
        cd ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization

        echo 'registering' $T1_Template 'to' $MNI_Template

        antsRegistration --dimensionality 3 --float 0 \
        --output [warpToMNIParams_${this_T1_core_file_name},warpToMNIEstimate_${this_T1_core_file_name}.nii] \
        --interpolation Linear \
        --winsorize-image-intensities [0.01,0.99] \
        --use-histogram-matching 1 \
        --initial-moving-transform [$MNI_Template,$T1_Template,1] \
        --transform Rigid[0.1] \
        --metric MI[$MNI_Template,$T1_Template,1,64,Regular,.5] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform Affine[0.1] \
        --metric MI[$MNI_Template,$T1_Template,1,64,Regular,.5] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox \
        --transform SyN[0.1,3,0] \
        --metric CC[$MNI_Template,$T1_Template,1,2] \
        --convergence [100x70x50x20,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0vox
    
    
        #Normalize DWI to MNI by applying transforms
        echo "Normalize DWI to MNI by applying transforms"
        cp ${Template_dir}/MNI_2mm.nii ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization

        antsApplyTransforms -d 3 -e 3 -i warpedToT1_${this_core_file_name}.nii.gz \
        -r MNI_2mm.nii \
        -n BSpline -o warpedToMNI_${this_core_file_name}.nii.gz \
        -t [warpToMNIParams_${this_T1_core_file_name}1Warp.nii.gz] \
        -t [warpToMNIParams_${this_T1_core_file_name}0GenericAffine.mat,0] -v
        
        echo "Normalize brain mask to MNI by applying transforms"
        #normliaze brain mask (you will need this for dtifit)
        antsApplyTransforms -d 3 \
        -i warpedToT1_se_epi_unwarped_brain_mask.nii.gz \
        -r MNI_2mm.nii \
        -n GenericLabel -o warpedToMNI_se_epi_unwarped_brain_mask.nii.gz \
        -t [warpToMNIParams_${this_T1_core_file_name}1Warp.nii.gz] \
        -t [warpToMNIParams_${this_T1_core_file_name}0GenericAffine.mat,0] -v
    
    fi
    
    if [[ $this_preprocessing_step == "copyfiles_normalizeddwi" ]]; then
        cd ${Subject_dir}/${dwi_folder_name}/ANTS_Normalization
        
        echo "Copy normalized DWI to main folder"
        cp warpedToMNI_se_epi_unwarped_brain_mask.nii.gz ${Subject_dir}/${dwi_folder_name}
        cp warpedToMNI_${this_core_file_name}.nii.gz ${Subject_dir}/${dwi_folder_name}
    fi
    
    if [[ $this_preprocessing_step == "dtifit_dwi" ]]; then
        cd ${Subject_dir}/${dwi_folder_name}
        
        echo "Fit tensors to normalized DWI"
        dtifit -k warpedToMNI_eddycorrected_denoised_unringed_dwi.nii.gz \
        -o tensorfit_warpedToMNI_eddycorrected_denoised_unringed_dwi \
        -m warpedToMNI_se_epi_unwarped_brain_mask.nii.gz -r dwi.bvec -b dwi.bval --save_tensor
    fi
    
    
   if [[ $this_preprocessing_step == "eigenvalues_dtialps" ]]; then
        
        echo "extracting eigenvalues for DTIALPS"
        
        ROIloc_LAssociation=${ROIfolder}/LAssociation2mm.nii.gz
        ROIloc_LProjection=${ROIfolder}/LProjection2mm.nii.gz
        ROIloc_RAssociation=${ROIfolder}/RAssociation2mm.nii.gz
        ROIloc_RProjection=${ROIfolder}/RProjection2mm.nii.gz

        cd ${Subject_dir}/${dwi_folder_name}
   
        tensorfitL1=tensorfit_warpedToMNI_eddycorrected_denoised_unringed_dwi_L1.nii.gz
        tensorfitL2=tensorfit_warpedToMNI_eeddycorrected_denoised_unringed_dwi_L2.nii.gz
        tensorfitL3=tensorfit_warpedToMNI_eddycorrected_denoised_unringed_dwi_L3.nii.gz

        fslmeants -i ${tensorfitL1} -o L1_LAssociation_mean.txt -m ${ROIloc_LAssociation}
        fslmeants -i ${tensorfitL2} -o L2_LAssociation_mean.txt -m ${ROIloc_LAssociation}
        fslmeants -i ${tensorfitL3} -o L3_LAssociation_mean.txt -m ${ROIloc_LAssociation}

        fslmeants -i ${tensorfitL1} -o L1_LProjection_mean.txt -m ${ROIloc_LProjection}
        fslmeants -i ${tensorfitL2} -o L2_LProjection_mean.txt -m ${ROIloc_LProjection}
        fslmeants -i ${tensorfitL3} -o L3_LProjection_mean.txt -m ${ROIloc_LProjection}

        fslmeants -i ${tensorfitL1} -o L1_RAssociation_mean.txt -m ${ROIloc_RAssociation}
        fslmeants -i ${tensorfitL2} -o L2_RAssociation_mean.txt -m ${ROIloc_RAssociation}
        fslmeants -i ${tensorfitL3} -o L3_RAssociation_mean.txt -m ${ROIloc_RAssociation}

        fslmeants -i ${tensorfitL1} -o L1_RProjection_mean.txt -m ${ROIloc_RProjection}
        fslmeants -i ${tensorfitL2} -o L2_RProjection_mean.txt -m ${ROIloc_RProjection}
        fslmeants -i ${tensorfitL3} -o L3_RProjection_mean.txt -m ${ROIloc_RProjection}

    fi

done
