"""Disposable real rollback child/parent and immutable RESULT flow, no live route."""
import os
from staging_write_cycle_windows_check import main

if __name__ == '__main__':
    os.environ['AUTHWIRE_ROLLBACK_AUTHORIZATION_CHECK'] = '1'
    os.environ['AUTHWIRE_ROLLBACK_EXECUTION_CHECK'] = '1'
    main()
