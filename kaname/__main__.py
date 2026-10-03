import argparse
from .server import DevelopmentServer


def main():
    parser = argparse.ArgumentParser(description='KANAME local development panel')
    parser.add_argument('--state-dir', default='kaname-state')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error('port must be between 1 and 65535')
    with DevelopmentServer(args.state_dir, args.port) as server:
        print(f'KANAME development panel: http://127.0.0.1:{server.server_port}')
        print('Panel login: username and password. See README for the first-install account.')
        print('Development only. Windows AD catalog is supported; enrollment, RADIUS and OVF image are pending.')
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
