import argparse
import signal
from .server import DevelopmentServer


def main():
    parser = argparse.ArgumentParser(description='KANAME local development panel')
    parser.add_argument('--state-dir', default='kaname-state')
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--listen', default='127.0.0.1')
    parser.add_argument('--tls-cert')
    parser.add_argument('--tls-key')
    parser.add_argument('--public-name')
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error('port must be between 1 and 65535')
    def stop_signal(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop_signal)
    with DevelopmentServer(args.state_dir, args.port, listen=args.listen, tls_cert=args.tls_cert,
                           tls_key=args.tls_key, public_name=args.public_name) as server:
        scheme = 'https' if server.tls else 'http'
        print(f'KANAME laboratory panel: {scheme}://{args.listen}:{server.server_port}')
        print('Panel login: username and password. See README for the first-install account.')
        print('Laboratory only. Protected AD catalog adapters are available; enrollment, production RADIUS and OVF are pending.')
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == '__main__':
    main()
