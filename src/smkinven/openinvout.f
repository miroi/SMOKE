
        SUBROUTINE OPENPNTS( ENAME, ANAME, SDEV )

C***********************************************************************
C  subroutine body starts at line 
C
C  DESCRIPTION:
C      This subroutine sets up the header and variables for the I/O API 
C      inventory file, and opens the I/O API and ASCII files for the SMOKE
C      point source inventory.
C
C  PRECONDITIONS REQUIRED:
C      Correct number of pollutants and names EINAM are set
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C      Subroutines: I/O API subroutines, BLDENAMS
C      Functions: I/O API functions, VERCHAR
C
C  REVISION  HISTORY:
C      Created 10/98 by M. Houyoux
C
C****************************************************************************/
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 1998, MCNC--North Carolina Supercomputing Center
C All Rights Reserved
C
C See file COPYRIGHT for conditions of use.
C
C Environmental Programs Group
C MCNC--North Carolina Supercomputing Center
C P.O. Box 12889
C Research Triangle Park, NC  27709-2889
C
C env_progs@mcnc.org
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***************************************************************************

C.........  MODULES for public variables
C.........  This module contains the lists of unique source characteristics
        USE MODLISTS

C.........  This module contains the information about the source category
        USE MODINFO

        IMPLICIT NONE

C...........   INCLUDES

        INCLUDE 'EMCNST3.EXT'   !  emissions constat parameters
        INCLUDE 'PARMS3.EXT'    !  I/O API parameters
        INCLUDE 'IODECL3.EXT'   !  I/O API function declarations
        INCLUDE 'FDESC3.EXT'    !  I/O API file description data structures.

C...........   EXTERNAL FUNCTIONS and their descriptionsNRAWIN
        CHARACTER*2     CRLF
        INTEGER         PROMPTFFILE
        CHARACTER(LEN=NAMLEN3) PROMPTMFILE
        CHARACTER*16    VERCHAR

        EXTERNAL CRLF, PROMPTFFILE, PROMPTMFILE, VERCHAR

C...........   SUBROUTINE ARGUMENTS
        CHARACTER(*), INTENT(IN OUT) :: ENAME ! emis i/o api inven logical name
        CHARACTER(*), INTENT(IN OUT) :: ANAME ! emis ASCII inven logical name
        INTEGER     , INTENT(OUT)    :: SDEV  ! ascii output inven file unit no.

C...........   LOCAL PARAMETERS
        CHARACTER*50, PARAMETER :: SCCSW  = '@(#)$Id$'  ! SCCS string with vers no.

C...........   Names, Units, types, & descriptions for pollutant-specific 
C              output variables

        CHARACTER(LEN=IOVLEN3) EONAMES( NIPOL,NPTPPOL3 ) ! Names 
        INTEGER                EOTYPES( NIPOL,NPTPPOL3 ) ! Types (Real or Int) 
        CHARACTER(LEN=IOULEN3) EOUNITS( NIPOL,NPTPPOL3 ) ! Units  
        CHARACTER(LEN=IODLEN3) EODESCS( NIPOL,NPTPPOL3 ) ! Dscriptions  

C...........   Other local variables

        INTEGER       I, J, L1, L2, V     ! counter and indices
        INTEGER       NIOVARS   ! Number of I/O API file non-emis variables
        INTEGER       NPOLMAX   ! Max no of pollutants, based on I/O API

        CHARACTER*300 MESG      ! message buffer 

        CHARACTER*16 :: PROGNAME = 'OPENPNTS' ! program name

C***********************************************************************
C   begin body of subroutine OPENPNTS

C.........  Check number of output variables against I/O API maximum

        NIOVARS = NPTVAR3 + NPTPPOL3 * NIPOL
        NPOLMAX = INT( ( MXVARS3 - NPTVAR3 ) / NPTPPOL3 )

C.........  If there are too many output variables, reset NIPOL

        IF( NIOVARS .GT. MXVARS3 ) THEN

            WRITE( MESG,94010 ) 
     &             'WARNING: Maximum number of pollutants that can ' //
     &             'be written to the' // CRLF() // BLANK5 //
     &             '         I/O API file is', NPOLMAX, 
     &             '. This limitation is caused by' // CRLF()// BLANK5//
     &             '         the I/O API variable limit of', MXVARS3,'.'
            CALL M3MSG2( MESG )
 
            WRITE( MESG,94010 ) 
     &             'WARNING: Reseting number of output pollutants to ',
     &             NPOLMAX
            CALL M3MSG2( MESG )

            NIPOL   = NPOLMAX
            NIOVARS = NPTVAR3 + NPTPPOL3 * NIPOL

        ENDIF

C.........  Determine the base year of the inventory
        CALL GETBASYR( NSRC, BYEAR )

C.........  Set up for opening I/O API output file header

        CALL HDRMISS3  ! Initialize for emissions 

        NVARS3D = NIOVARS
        NROWS3D = NSRC   !  number of rows = # of point sources.

        FDESC3D( 1 ) = 'Point source inventory'
        FDESC3D( 2 ) = '/FROM/ ' // PROGNAME
        FDESC3D( 3 ) = '/VERSION/ ' // VERCHAR( SCCSW )
        WRITE( FDESC3D( 4 ),94010 ) '/NON POLLUTANT/ ', NPTVAR3
        WRITE( FDESC3D( 5 ),94010 ) '/PER POLLUTANT/ ', NPTPPOL3 
        WRITE( FDESC3D( 6 ),94010 ) '/NUMBER CHARS/ ' , NCHARS 
        WRITE( FDESC3D( 7 ),94010 ) '/SCC POSITION/ ' , JSCC 
        WRITE( FDESC3D( 8 ),94010 ) '/BASE YEAR/ '    , BYEAR 

C NOTE: Add /BASE YEAR/ packet to FDESC3D.  If more than one base year is used,
C       use the most common one.  In either case, write a message about 
C       which is being used.
C NOTE: Need to add packet to FDESC that has the "base year" from the
C environment variable G_SDATE


C.........  Define source characteristic variables that are not strings

        J = 1
        VNAME3D( J ) = 'IFIP'
        VTYPE3D( J ) = M3INT
        UNITS3D( J ) = 'n/a'
        VDESC3D( J ) = 'State and county FIPS code'
        J = J + 1

        VNAME3D( J ) = 'ISIC'
        VTYPE3D( J ) = M3INT
        UNITS3D( J ) = 'n/a'
        VDESC3D( J ) = 'Source Industrial Code'
        J = J + 1

        VNAME3D( J )= 'IORIS'
        VTYPE3D( J )= M3INT
        UNITS3D( J )= 'n/a'
        VDESC3D( J )= 'Office of the Regulatory Information System code'
        J = J + 1

        VNAME3D( J ) = 'TZONES'
        VTYPE3D( J ) = M3INT
        UNITS3D( J ) = 'n/a'
        VDESC3D( J ) = 'Time zone for site'
        J = J + 1

        VNAME3D( J ) = 'TPFLAG'
        VTYPE3D( J ) = M3INT
        UNITS3D( J ) = 'T|2? T|3?'
        VDESC3D( J ) = 'Use week(2), month(3) temporal profiles or not'
        J = J + 1

        VNAME3D( J ) = 'INVYR'
        VTYPE3D( J ) = M3INT
        UNITS3D( J ) = 'year AD'
        VDESC3D( J ) = 'Year of inventory for this record'
        J = J + 1

        VNAME3D( J ) = 'XLOCA'
        VTYPE3D( J ) = M3REAL
        UNITS3D( J ) = 'degrees'
        VDESC3D( J ) = 'longitude'
        J = J + 1

        VNAME3D( J ) = 'YLOCA'
        VTYPE3D( J ) = M3REAL
        UNITS3D( J ) = 'degrees'
        VDESC3D( J ) = 'latitude'
        J = J + 1

        VNAME3D( J ) = 'STKHT'
        VTYPE3D( J ) = M3REAL
        UNITS3D( J ) = 'm'
        VDESC3D( J ) = 'Stack height'
        J = J + 1

        VNAME3D( J ) = 'STKDM'
        VTYPE3D( J ) = M3REAL
        UNITS3D( J ) = 'm'
        VDESC3D( J ) = 'Stack diameter'
        J = J + 1

        VNAME3D( J ) = 'STKTK'
        VTYPE3D( J ) = M3REAL
        UNITS3D( J ) = 'deg K'
        VDESC3D( J ) = 'Stack exhaust temperature'
        J = J + 1

        VNAME3D( J ) = 'STKVE'
        VTYPE3D( J ) = M3REAL
        UNITS3D( J ) = 'm/s'
        VDESC3D( J ) = 'Stack exhaust velocity'
        J = J + 1

C.........  Get names, units, etc. of output pollutant-specific records
        CALL BLDENAMS( 'POINT', NIPOL, NPTPPOL3, EINAM, 
     &                 EONAMES, EOUNITS, EOTYPES, EODESCS )

        DO V = 1 , NIPOL
            
            DO I = 1, NPTPPOL3 ! Loop through number of variables per pollutant

                VNAME3D( J ) = EONAMES( V, I )
                VTYPE3D( J ) = EOTYPES( V, I )
                UNITS3D( J ) = EOUNITS( V, I )
                VDESC3D( J ) = EODESCS( V, I )
                J = J + 1

            ENDDO    !  end loop on number of variables per pollutant

        ENDDO        !  end loop on inventory pollutants V

C.........  Prompt for and open I/O API output file
        ENAME= PROMPTMFILE( 
     &       'Enter logical name for the I/O API INVENTORY output file',
     &       FSUNKN3, ENAME, PROGNAME )
        
C.........  Prompt for and open ASCII output file
        SDEV= PROMPTFFILE( 
     &      'Enter logical name for the ASCII INVENTORY output file',
     &      .FALSE., .TRUE., ANAME, PROGNAME )

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

C...........   Internal buffering formats............ 94xxx

94010   FORMAT( 10( A, :, I8, :, 1X ) )
 
        END

