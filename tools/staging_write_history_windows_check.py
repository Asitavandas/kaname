"""Governed local cycle archival, actual CNG/NTFS and real core continuation."""
import os
from staging_write_cycle_windows_check import main

if __name__ == '__main__':
    os.environ['AUTHWIRE_ROLLBACK_AUTHORIZATION_CHECK'] = '1'
    os.environ['AUTHWIRE_WRITE_LIFECYCLE_CHECK'] = '1'
    os.environ['AUTHWIRE_WRITE_HISTORY_CHECK'] = '1'
    main()
