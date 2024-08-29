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


# example >> check_roi_boundaries.sh subject_id folder_name file_to_check roi_settings_file.txt
# example >> check_roi_boundaries.sh 1013 04_rsfMRI/ANTS_Normalization smoothed_warpedToMNI_unwarpedRealigned_slicetimed_RestingState.nii ROI_settings_conn_wu120_all_wb_cb.txt

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
        SubjID=$this_argument
	else
		preprocessing_steps[argument_counter]="$this_argument"
	fi
	(( argument_counter++ ))
done
export MATLABPATH=${Matlab_dir}/helper
ml matlab/2020b
ml gcc/5.2.0; ml ants ## ml gcc/9.3.0; ml ants/2.3.4
ml fsl/6.0.3

cd $Subject_dir

lines_to_ignore=$(awk '/#/{print NR}' file_settings.txt)
t1_line_numbers_in_file_info=$(awk '/t1/{print NR}' file_settings.txt)
t1_line_numbers_to_process=$t1_line_numbers_in_file_info
this_index_t1=0
for item_to_ignore in ${lines_to_ignore[@]}; do
  	for item_to_check in ${t1_line_numbers_to_process[@]}; do
  		if [[ $item_to_check == $item_to_ignore ]]; then 
  			remove_this_item_t1[$this_index_t1]=$item_to_ignore
  			(( this_index_t1++ ))
  		fi
  	done
done
for item_to_remove_t1 in ${remove_this_item_t1[@]}; do
	t1_line_numbers_to_process=$(echo ${t1_line_numbers_to_process[@]/$item_to_remove_t1})
done	
this_index=0
for this_line_number in ${t1_line_numbers_to_process[@]}; do
	t1_processed_folder_name_array[$this_index]=$(cat file_settings.txt | sed -n ${this_line_number}p | cut -d ',' -f2)
	(( this_index++ ))
done



t1_processed_folder_names=$(echo "${t1_processed_folder_name_array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

for this_preprocessing_step in ${preprocessing_steps[@]}; do
	if [[ $this_preprocessing_step == "n4_bias_correction" ]]; then
		this_t1_folder=($t1_processed_folder_names)

		cd ${Subject_dir}/${this_t1_folder}/
        gunzip t1.nii.gz
		# N4BiasFieldCorrection -i SkullStripped_T1.nii -o biascorrected_SkullStripped_T1.nii
		N4BiasFieldCorrection -i t1.nii -o biascorrected_T1.nii
	fi
	if [[ $this_preprocessing_step == "skull_strip_t1_4_ants" ]]; then
		this_t1_folder=($t1_processed_folder_names)

		cp ${Template_dir}/TPM.nii ${Subject_dir}/${this_t1_folder}
		cd ${Subject_dir}/${this_t1_folder}/
		matlab -nodesktop -nosplash -r "try; segment_t1; catch; end; quit"
		matlab -nodesktop -nosplash -r "try; skull_strip_t1; catch; end; quit"
	fi
	if [[ $this_preprocessing_step == "copy_t1" ]]; then
		this_t1_folder=($t1_processed_folder_names)

		subject=$SubjID
		cd ${Subject_dir}/${this_t1_folder}/
		cp T1.nii ${subject}.nii
		gzip ${subject}.nii
		cp -t /blue/tpengzhao/SHARED/TKA_dataset_peng/Ceres_Raw_T1 ${subject}.nii.gz
	fi
	if [[ $this_preprocessing_step == "check_skullstrip" ]]; then
		this_t1_folder=($t1_processed_folder_names)

		cd ${Subject_dir}/${this_t1_folder}/
		echo checking skull_strip_t1 ${Subject_dir}
		ml itksnap
		itksnap -g T1.nii -o SkullStripped_biascorrected_T1.nii
	fi
done
