
        SUBROUTINE PROCEMSPT( FDEV, FNAME, CFLAG, WFLAG )

C***********************************************************************
C  subroutine body starts at line 232
C
C  DESCRIPTION:
C      This subroutine reads the EMS-95 point files and processes the
C      source characteristics.
C
C  PRECONDITIONS REQUIRED:
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C      Copied from rdemspt.f by C. Seppanen (2/03)
C
C****************************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2002, MCNC Environmental Modeling Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Modeling Center
C MCNC
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C smoke@emc.mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C...........   MODULES for public variables
C.........  This module contains the information about the source category
        USE MODINFO, ONLY: NSRC
        
C...........   This module contains the source ararys
        USE MODSOURC, ONLY: CSOURC
        
C.........  This module contains the lists of unique inventory information
        USE MODLISTS, ONLY: LSTSTR

        IMPLICIT NONE

C...........   INCLUDES
        INCLUDE 'EMCNST3.EXT'   !  emissions constant parameters

C...........   EXTERNAL FUNCTIONS and their descriptions:
        CHARACTER*2     CRLF
        INTEGER         GETINVYR
        INTEGER         STR2INT
        
        EXTERNAL        CRLF, GETINVYR, STR2INT

C...........   SUBROUTINE ARGUMENTS
        INTEGER,          INTENT (IN) :: FDEV   ! unit no. of inv file
        CHARACTER(LEN=*), INTENT (IN) :: FNAME  ! logical name of inv file
        LOGICAL,          INTENT (IN) :: CFLAG  ! true: recalc vel w/ flow and diam
        LOGICAL,          INTENT (IN) :: WFLAG  ! true: convert lat-lons to western hemisphere

C...........   Local allocatable arrays
        INTEGER, ALLOCATABLE :: UTMZONE( : )     ! UTM zone from facility file
        INTEGER, ALLOCATABLE :: FIPTOCSRC( :,: ) ! index by FIP into CSOURC arary

C...........   Other local variables
        INTEGER              I, J                   ! counter
        INTEGER              IOS                    ! I/O status
        INTEGER              PCNTY                ! previous state FIPS code
        INTEGER              CNTY                 ! current state code
        INTEGER              NCNTY                ! no. states in inventory

        CHARACTER(LEN=8)     PFILTYPE               ! previous file type
        CHARACTER(LEN=300)   INFILE                 ! inventory file name
        CHARACTER(LEN=300)   MESG                   ! message buffer

        CHARACTER(LEN=16) :: PROGNAME = 'PROCEMSPT' ! program name

C***********************************************************************
C   begin body of subroutine PROCEMSPT

C.........  Create FIPTOCSRC array, to index into CSOURC array based on state

C.........  Count total number of counties in the inventory
        PCNTY = 0
        NCNTY = 0
        
        DO I = 1, NSRC
        
            CNTY = STR2INT( CSOURC( I )( 1:6 ) )
            IF( CNTY /= PCNTY ) THEN
                NCNTY = NCNTY + 1
                PCNTY = CNTY
            END IF
        
        END DO

C.........  Allocate memory - use NCNTY+1 so that last entry can be size of CSOURC array
        ALLOCATE( FIPTOCSRC( NCNTY+1,2 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'FIPTOCSRC', PROGNAME )
        
C.........  Fill in array with index values
        PCNTY = 0
        J = 0
        
        DO I = 1, NSRC
            CNTY = STR2INT( CSOURC( I )( 1:6 ) )
            IF( CNTY /= PCNTY ) THEN
                J = J + 1

C.................  Make sure that J is within array bounds                
                IF( J > NCNTY + 1 ) EXIT
                
                FIPTOCSRC( J,1 ) = CNTY
                FIPTOCSRC( J,2 ) = I
                PCNTY = CNTY
            END IF
        END DO
        
C.........  Fill in values for final position in FIPTOCSRC array
        FIPTOCSRC( NCNTY+1,1 ) = 1000000  ! fake FIPS code larger than any real ones
        FIPTOCSRC( NCNTY+1,2 ) = NSRC + 1

C.........  Allocate local arrays
        ALLOCATE( UTMZONE( NSRC ), STAT=IOS )
        CALL CHECKMEM( IOS, 'UTMZONE', PROGNAME )
        UTMZONE = 0

C.........  Set previous file type to stack (as if we've read a complete set of files)
        PFILTYPE = 'STACK'

C.........  Loop over all files in inventory list file
        DO I = 1, SIZE( LSTSTR )

C.............  Don't read emission file since it will be read in RDINVDATA
            IF( PFILTYPE == 'DEVICE' ) THEN
                PFILTYPE = 'EMISSION'
                CYCLE
            END IF

            INFILE = LSTSTR( I )
            
C.............  Check for INVYEAR packet
            IF( GETINVYR( INFILE ) > 0 ) CYCLE

C.............  Open current file
            OPEN( FDEV, FILE=INFILE, STATUS='OLD', IOSTAT=IOS )

            IF( IOS /= 0 ) THEN
                    
                WRITE( MESG,94010 ) 'Problem at line ', I, 'of ' // 
     &                 TRIM( FNAME ) // '.' // ' Could not open ' //
     &                 'file:' // CRLF() // BLANK5 // TRIM( INFILE ) 
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        
            ELSE
                WRITE( MESG,94010 ) 'Successful OPEN for ' //
     &                 'inventory file:' // CRLF() // BLANK5 // 
     &                 TRIM( INFILE )
                CALL M3MSG2( MESG ) 
        
            END IF

C.............  Call correct reader based on previous file type
            SELECT CASE( PFILTYPE )
            
            CASE( 'EMISSION' )
                PFILTYPE = 'FACILITY'
                CALL RDFACEMSPT( FDEV, UTMZONE, NCNTY, FIPTOCSRC )
                
            CASE( 'FACILITY' )
                PFILTYPE = 'PROCESS'
                CALL RDPROCEMSPT( FDEV, NCNTY, FIPTOCSRC )
            
            CASE( 'PROCESS' )
                PFILTYPE = 'STACK'
                CALL RDSTKEMSPT( FDEV, CFLAG, WFLAG, UTMZONE, 
     &                           NCNTY, FIPTOCSRC )
            
            CASE( 'STACK' )
                PFILTYPE = 'DEVICE'
                CALL RDDEVEMSPT( FDEV, NCNTY, FIPTOCSRC )
            
            END SELECT
            
            CLOSE( FDEV )          
            
        END DO  ! loop over all files in inventory list

C.........  Deallocate local memory
        DEALLOCATE( FIPTOCSRC, UTMZONE )

C******************  FORMAT  STATEMENTS   ******************************

C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )

94125   FORMAT( I5 )

94300   FORMAT( A, I2.2, A, I2.2, A )

        END SUBROUTINE PROCEMSPT