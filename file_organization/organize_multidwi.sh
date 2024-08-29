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
    if    [[ $argument_counter == 0 ]]; then
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

base_directory=$Subject_dir

#loop through pre and post
#for thisdwiprepostfolder in "$base_directory"/*; do
thisdwiprepostfolder=$Subject_dir

cd "${thisdwiprepostfolder}/dwi"

    if [ -e *acq-6_dwi.bval ]; then
        mkdir -p "${thisdwiprepostfolder}/dwi/acq-6_dwi"
        mkdir -p "${thisdwiprepostfolder}/dwi/acq-6_dwi/json/"
                
        mv *acq-6_dwi.nii* "${thisdwiprepostfolder}/dwi/acq-6_dwi"
        mv *acq-6_dwi.json "${thisdwiprepostfolder}/dwi/acq-6_dwi/json"
        mv *acq-6_dwi.bval "${thisdwiprepostfolder}/dwi/acq-6_dwi"
        mv *acq-6_dwi.bvec "${thisdwiprepostfolder}/dwi/acq-6_dwi"
        
        cp /blue/tpengzhao/SHARED/tka002_dicoms/pre/EP2D_DIFF_6DIR_LOWB_0009/EP2D_DIFF_6DIR_LOWB_0009_ep2d_diff_6DIR_LOWB_20130908175018_9.json ${thisdwiprepostfolder}/dwi/acq-6_dwi
    fi

    if [ -e *acq-64_dwi.bval ]; then
        mkdir -p "${thisdwiprepostfolder}/dwi/acq-64_dwi"
        mkdir -p "${thisdwiprepostfolder}/dwi/acq-64_dwi/json/"
        
        mv *acq-64_dwi.nii* "${thisdwiprepostfolder}/dwi/acq-64_dwi"
        mv *acq-64_dwi.json "${thisdwiprepostfolder}/dwi/acq-64_dwi/json"
        mv *acq-64_dwi.bval "${thisdwiprepostfolder}/dwi/acq-64_dwi"
        mv *acq-64_dwi.bvec "${thisdwiprepostfolder}/dwi/acq-64_dwi"
        
        cp /blue/tpengzhao/SHARED/tka002_dicoms/pre/EP2D_DIFF_64DIR_0013/EP2D_DIFF_64DIR_0013_ep2d_diff_64DIR_20130908175018_13.json ${thisdwiprepostfolder}/dwi/acq-64_dwi
    fi

    if [ -e *merged_dwi.bval ]; then
        mkdir -p "${thisdwiprepostfolder}/dwi/merged_dwi"
        mv *merged_dwi_ec.nii* "${thisdwiprepostfolder}/dwi/merged_dwi"
        mv *merged_dwi.bval "${thisdwiprepostfolder}/dwi/merged_dwi"
        mv *merged_dwi_rot.bvec "${thisdwiprepostfolder}/dwi/merged_dwi"
    fi

#done


