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

Matlab_dir=$2

export MATLABPATH=${Matlab_dir}/helper

ml matlab/2020b

cd ${Subject_dir}/Raw/MRI_files/T1_MPRAGE_SAG_ISO_8MM_000*
matlab -nodesktop -nosplash -r "try; save_subject_info; catch; end; quit"
echo $SUB info saved took $SECONDS seconds to execute
