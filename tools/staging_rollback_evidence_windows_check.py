"""Read-only rollback bridge against two real observed/accepted fixture stages.

Uses the existing 13-case CNG/TLS/SQLite/signed-child/SMB driver unchanged.
Rollback offers and directory/service identity observations are explicit stubs;
this does not test issuance/consumption/execution of a rollback authorization.
"""
import os
from staging_write_cycle_windows_check import main

if __name__ == '__main__':
    os.environ['AUTHWIRE_ROLLBACK_EVIDENCE_CHECK'] = '1'
    main()
