"""Separate rollback approval/grant/use in the disposable native flow harness."""
import os
from staging_write_cycle_windows_check import main

if __name__ == '__main__':
    os.environ['AUTHWIRE_ROLLBACK_AUTHORIZATION_CHECK'] = '1'
    main()
