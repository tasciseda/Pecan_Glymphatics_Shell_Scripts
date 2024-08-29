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

Subject_dir=$1

#####################################################################################
ml mricrogl
ml gcc/5.2.0
ml pigz


copyandrenamefiles(){
    
	this_raw_folder_name=$(cat file_settings.txt | sed -n ${this_folder_row}p | cut -d ',' -f1)
	this_processed_folder_name=$(cat file_settings.txt | sed -n ${this_folder_row}p | cut -d ',' -f2)
	this_processed_file_name=$(cat file_settings.txt | sed -n ${this_folder_row}p | cut -d ',' -f3)
    thisfiletype=$(cat file_settings.txt | sed -n ${this_folder_row}p | cut -d ',' -f4)

	cd ${Subject_dir}/$this_raw_folder_name
    
    mkdir -p "${Subject_dir}/${this_processed_folder_name}"
	
	for nii_file in *.nii*; do
        #copy nifti file into processed folder
        cp ${nii_file} "${Subject_dir}/${this_processed_folder_name}";
        
        cd ${Subject_dir}/${this_processed_folder_name}
        #rename file to processed file name
		mv -v ${nii_file} $this_processed_file_name.nii.gz
        cd ${Subject_dir}/$this_raw_folder_name
		
	done

	for json_file in *.json*; do
        #copy json
        cp ${json_file} "${Subject_dir}/${this_processed_folder_name}"
        
        cd ${Subject_dir}/${this_processed_folder_name}
        
        #rename file to processed file name
        mv -v ${json_file} $this_processed_file_name.json

        cd ${Subject_dir}/$this_raw_folder_name
        
	done

	if [ -e *.bval* ]; then
        
            for bval_file in *.bval* ; do
                cp ${bval_file} "${Subject_dir}/${this_processed_folder_name}";
               cd ${Subject_dir}/${this_processed_folder_name}
                mv -v ${bval_file} $this_processed_file_name.bval
                cd ${Subject_dir}/$this_raw_folder_name
            done
            
            for bvec_file in  *.bvec* ; do
                cp ${bvec_file} "${Subject_dir}/${this_processed_folder_name}";
                cd ${Subject_dir}/${this_processed_folder_name}
                mv -v ${bvec_file} $this_processed_file_name.bvec
                cd ${Subject_dir}/$this_raw_folder_name
            done
	fi
    
	cd $Subject_dir
}



cd $Subject_dir

lines_to_ignore=$(awk '/#/{print NR}' file_settings.txt)
number_of_folders_to_extract=$(awk 'END{print NR}' file_settings.txt)
for (( this_folder_row=1; this_folder_row<=${number_of_folders_to_extract}; this_folder_row++ )); do
	if ! [[ ${lines_to_ignore[*]} =~ $this_folder_row ]]; then
		copyandrenamefiles $Subject_dir $this_folder_row &
	fi
done
wait
echo "This script took $SECONDS seconds to execute"
