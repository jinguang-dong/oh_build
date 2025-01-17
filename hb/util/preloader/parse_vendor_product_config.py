#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (c) 2023 Huawei Device Co., Ltd.
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

import argparse
import sys
import json
import re
import os


def get_features(features):
    feats = {}
    for feat in features:
        if not feat:
            continue
        match = feat.index("=")
        if match <= 0:
            print("Warning: invalid feature [{}]".format(feat))
            continue
        key = feat[:match].strip()
        val = feat[match + 1:].strip().strip('"')
        if val == 'true':
            feats[key] = True
        elif val == 'false':
            feats[key] = False
        elif re.match(r'[0-9]+', val):
            feats[key] = int(val)
        else:
            feats[key] = val.replace('\"', '"')

    pairs = dict()
    pairs['features'] = feats
    return pairs


def get_syscap(syscap):
    feats = {}
    for feat in syscap:
        if not feat:
            continue
        if '=' not in feat:
            raise Exception("Error: invalid syscap [{}]".format(feat))
        match = feat.index("=")
        key = feat[:match].strip()
        val = feat[match + 1:].strip().strip('"')
        if val == 'true':
            feats[key] = True
        elif val == 'false':
            feats[key] = False
        elif re.match(r'[0-9]+', val):
            feats[key] = int(val)
        else:
            feats[key] = val.replace('\"', '"')

    pairs = dict()
    pairs['syscap'] = feats
    return pairs


def get_exclusion_modules(exclusions):
    pairs = dict()
    pairs['exclusions'] = exclusions
    return pairs


def from_ss_to_parts(subsystems):
    parts = dict()
    for subsystem in subsystems:
        ss_name = subsystem.get('subsystem')
        components = subsystem.get('components')
        if components:
            for com in components:
                com_name = com.get('component')
                features = com.get('features')
                syscap = com.get('syscap')
                exclusions = com.get('exclusions')
                if features:
                    pairs = get_features(features)
                    parts['{}:{}'.format(ss_name, com_name)] = pairs
                else:
                    parts['{}:{}'.format(ss_name, com_name)] = dict()
                if syscap:
                    pairs = get_syscap(syscap)
                    parts.get('{}:{}'.format(ss_name, com_name)).update(pairs)
                if exclusions:
                    pairs = get_exclusion_modules(exclusions)
                    parts.get('{}:{}'.format(ss_name, com_name)).update(pairs)
                # Copy other key-values
                for key, val in com.items():
                    if key in ['component', 'features', 'syscap', 'exclusions']:
                        continue
                    parts['{}:{}'.format(ss_name, com_name)][key] = val
    return parts


def transform(config):
    subsystems = config.get('subsystems')
    if subsystems:
        config.pop('subsystems')
        parts = from_ss_to_parts(subsystems)
        config['parts'] = parts
    return config


def save_transformed_config(config, output_file):
    new_config = json.dumps(config, indent=2, sort_keys=True)
    with open(output_file, 'wt') as fout:
        fout.write(new_config)


def get_product_config(config_dir, product_name, company):
    company_path = os.path.join(config_dir, company)
    if not os.path.isdir(company_path):
        raise Exception(f'Error: {company_path} is not a directory')

    for product in os.listdir(company_path):
        product_path = os.path.join(company_path, product)
        config_json = os.path.join(product_path, 'config.json')

        if os.path.isfile(config_json):
            with open(config_json, 'rb') as fin:
                config = json.load(fin)
                if product_name == config.get('product_name'):
                    return config
    raise Exception(f'Error: failed to get product config for {product_name}')


def get_vendor_parts_list(config):
    return transform(config).get('parts')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--product-name', required=True)
    parser.add_argument('--company', required=True)
    parser.add_argument('--config-dir', required=True)
    options = parser.parse_args()
    config = get_product_config(options.config_dir, options.product_name,
                                options.company)
    get_vendor_parts_list(config)


if __name__ == '__main__':
    sys.exit(main())
