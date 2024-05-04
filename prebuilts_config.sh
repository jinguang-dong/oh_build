#!/bin/bash
# Copyright (c) 2024 Huawei Device Co., Ltd.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e

script_path=$(cd $(dirname $0);pwd)
code_dir=$(dirname ${script_path})
home_path=$HOME
config_file="$script_path/prebuilts_config.json"
# 获取当前系统类型和CPU类型
target_os=$(uname -s | tr '[:upper:]' '[:lower:]')
target_cpu=$(uname -m | tr '[:upper:]' '[:lower:]')

# 运行Python命令
python3 "${script_path}/prebuilts_config.py" --code_path $code_dir --home_path $home_path --config_file $config_file --repo_https https://repo.huaweicloud.com --target_os $target_os --target_cpu $target_cpu

if [[ "${target_os}" == "linux" ]]; then
    sed -i "1s%.*%#!/usr/bin/env python3%" ${code_dir}/prebuilts/python/${target_os}-x86/3.10.2/bin/pip3.10
elif [[ "${target_os}" == "darwin" ]]; then
    sed -i "" "1s%.*%#!/use/bin/env python3%" ${code_dir}/prebuilts/python/${target_os}-x86/3.10.2/bin/pip3.10
fi

# llvm_ndk is merged form llvm and libcxx-ndk for compiling the native of hap
llvm_dir="${code_dir}/prebuilts/clang/ohos/linux-x86_64"
llvm_dir_win="${code_dir}/prebuilts/clang/ohos/windows-x86_64"
llvm_dir_mac_x86="${code_dir}/prebuilts/clang/ohos/darwin-x86_64"
llvm_dir_mac_arm64="${code_dir}/prebuilts/clang/ohos/darwin-arm64"
llvm_dir_list=($llvm_dir $llvm_dir_win $llvm_dir_mac_x86 $llvm_dir_mac_arm64)

# copy libcxx-ndk library outside c++
function copy_inside_cxx(){
for i in ${llvm_dir_list[@]}
do
    libcxx_dir="${i}/libcxx-ndk/lib"
    if [[ -d "${i}/libcxx-ndk" ]]; then
        for file in $(ls ${libcxx_dir})
        do
            if [ ! -d "${libcxx_dir}/${file}/c++" ];then
                $(mkdir -p ${libcxx_dir}/c++)
                $(cp -r ${libcxx_dir}/${file}/* ${libcxx_dir}/c++)
                $(mv ${libcxx_dir}/c++ ${libcxx_dir}/${file}/c++)
            fi
        done
    fi
done
}

function update_llvm_ndk(){
if [[ -e "${llvm_dir}/llvm_ndk" ]];then
  rm -rf "${llvm_dir}/llvm_ndk"
fi
mkdir -p "${llvm_dir}/llvm_ndk"
cp -af "${llvm_dir}/llvm/include" "${llvm_dir}/llvm_ndk"
cp -rfp "${llvm_dir}/libcxx-ndk/include" "${llvm_dir}/llvm_ndk"
}

function change_rustlib_name(){
rust_dir="${code_dir}/prebuilts/rustc/linux-x86_64/current/lib/rustlib/"
for file in $(find "$rust_dir" -path "$rust_dir/x86_64-unknown-linux-gnu" -prune -o -name "lib*.*")
do
    dir_name=${file%/*}
    file_name=${file##*/}
    file_prefix=$(echo "$file_name" | awk '{split($1, arr, "."); print arr[1]}')
    file_prefix=$(echo "$file_prefix" | awk '{split($1, arr, "-"); print arr[1]}')
    file_suffix=$(echo "$file_name" | awk '{split($1, arr, "."); print arr[2]}')
    if [[ "$file_suffix" != "rlib" && "$file_suffix" != "so" || "$file_prefix" == "librustc_demangle" || "$file_prefix" == "libcfg_if" || "$file_prefix" == "libunwind" ]]
    then
        continue
    fi
    if [[ "$file_suffix" == "rlib" ]]
    then
        if [[ "$file_prefix" == "libstd" || "$file_prefix" == "libtest" ]]
        then
            newfile_name="$file_prefix.dylib.rlib"
        else
            newfile_name="$file_prefix.rlib"
        fi
    fi

    if [[ "$file_suffix" == "so" ]]
    then
        newfile_name="$file_prefix.dylib.so"
    fi
    if [[ "$file_name" == "$newfile_name" ]]
    then
        continue
    fi
    mv $file "$dir_name/$newfile_name"
done
}

copy_inside_cxx
echo "======copy inside cxx finished!======"
