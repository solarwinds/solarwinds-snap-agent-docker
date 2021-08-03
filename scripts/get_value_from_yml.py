import yaml
import argparse

parser = argparse.ArgumentParser(description='Parse yml file')
parser.add_argument('--config', dest='config', action='store',
                    help='Configuration file')
parser.add_argument('--key', dest='key', action='store',
                    help='Key of the configuration parameter')
args = parser.parse_args()

print(yaml.load(open(args.config) , yaml.SafeLoader)[args.key])