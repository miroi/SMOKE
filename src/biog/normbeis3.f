
        PROGRAM NORMBEIS3

C***********************************************************************
C
C  DESCRIPTION:  Produces normalized biogenic emissions for use with
C                SMOKE-BEIS3 v0.9.
C
C  SUBROUTINES AND FUNCTIONS CALLED: RDB3FAC
C
C  REVISION  HISTORY: 3/00 Prototype, Jeff Vukovich
C
C***********************************************************************
C
C Project Title: Sparse Matrix Operator Kernel Emissions (SMOKE) Modeling
C                System
C File: @(#)$Id$
C
C COPYRIGHT (C) 2004, Environmental Modeling for Policy Development
C All Rights Reserved
C 
C Carolina Environmental Program
C University of North Carolina at Chapel Hill
C 137 E. Franklin St., CB# 6116
C Chapel Hill, NC 27599-6116
C 
C smoke@unc.edu
C
C Pathname: $Source$
C Last updated: $Date$ 
C
C***********************************************************************

C...........   MODULES for public variables

C...........   This module contains biogenic variables

        USE MODBEIS3, ONLY: NVEG, VEGID, LAI, LFBIO, WFAC, SLW, EMFAC,
     &                      AVGISOP, AVGMONO, AVGOVOC, AVGNO, AVGLAI
 
        IMPLICIT NONE

C...........   INCLUDES:

        INCLUDE 'PARMS3.EXT'      ! I/O API constants
        INCLUDE 'FDESC3.EXT'      ! I/O API file description data structure
        INCLUDE 'IODECL3.EXT'     ! I/O API function declarations
        INCLUDE 'EMCNST3.EXT'     !
        INCLUDE 'B3DIMS3.EXT'     ! BEIS3-related declarations

C...........   PARAMETERS and their descriptions:

C...........   LOCAL PARAMETERS

        CHARACTER*50, PARAMETER :: CVSW = '$Name$' ! CVS release tag
  
C...........   EXTERNAL FUNCTIONS and their descriptions:

        INTEGER         GETFLINE
        INTEGER         PROMPTFFILE
        CHARACTER*16    PROMPTMFILE
        INTEGER         TRIMLEN
        CHARACTER*16    VERCHAR

        EXTERNAL        GETFLINE, PROMPTFFILE, PROMPTMFILE,  
     &                  TRIMLEN, VERCHAR

C...........   LOCAL VARIABLES and their descriptions:

        INTEGER         B, C, R, I, J, K, L, M, N ! loop counters and subscripts
        INTEGER         IOS     !  I/O status result

        INTEGER         FDEV    !  unit number for emissions factor file
        INTEGER         LDEV    !  unit number for log file

        CHARACTER*16    ENAME   !  logical name for normalized emissions output
        CHARACTER*16    GNAME1  !  unit number for gridded land use file
        CHARACTER*16    GNAME2  !  unit number for gridded land use file
        CHARACTER*16    GRDNM   !  grid name
        CHARACTER*16, ALLOCATABLE  :: LUNAMA( : )  ! land use type names
        CHARACTER*16, ALLOCATABLE  :: LUNAMB( : )  ! land use type names
        CHARACTER*16    LUNAM   ! temporary tag for land use names    
        CHARACTER*16    GNAMET  !  unit number for gridded land use totals file

        CHARACTER*256   MESG    !  message buffer for M3EXIT()
        CHARACTER*4     BTMP    ! temporary tag for naming output variables

        INTEGER, ALLOCATABLE      :: LUINDX( : )   ! index for land use types
        INTEGER         NCOLS   ! no. of grid columns
        INTEGER         NGRID   ! no. of grid cells
        INTEGER         NROWS   ! no. of grid rows
        INTEGER         NVARSA  ! no. of land use types in land use file A
        INTEGER         NVARSB  ! no. of land use types in land use file B
        INTEGER         NVARST  ! total land use types = A + B
        INTEGER         IFOUND  ! used for checking land use vs. emis facs
        INTEGER         IUSDEC  ! USGS decid forest
        INTEGER         IUSBRD  ! USGS evbrdleaf
        INTEGER         IUSCON  ! USGS coniferfor
        INTEGER         IUSMIX  ! USGS mixed forest                         
        INTEGER         IUSSHR  ! USGS shrubland

        REAL, ALLOCATABLE    :: LUSE ( :, :, :  )  ! BELD3 land use data
        REAL, ALLOCATABLE    :: FIA ( :, : )       ! Forest inventory data

        REAL  SUMOVOC, SUMISOP, SUMMONO, SUMNO, SUMLAI       ! Summer emissions
        REAL  SUMOVOCW, SUMISOPW, SUMMONOW, SUMNOW, SUMLAIW  ! Winter emissions
        REAL  VEGAREA                                        ! Veg. area for 
        REAL  TOTFOR                                         ! USGS forest
        REAL  EFISOP, EFMONO, EFOVOC, EFNO                   ! Emission factors

        DOUBLE PRECISION   PRCNT2KM2                         ! Prcnt to km**2
        LOGICAL         EFLAG                                ! Error flag

        CHARACTER*16 :: PROGNAME = 'NORMBEIS3'   !  program name

C***********************************************************************
C   begin body of program NORMBIO

        LDEV = INIT3()

C.........  Write out copywrite, version, web address, header info, and prompt
C           to continue running the program.

        CALL INITEM( LDEV, CVSW, PROGNAME )
   
C.......   Get file name; open emission factors file

        FDEV = PROMPTFFILE( 
     &           'Enter logical name for EMISSION FACTORS file',
     &           .TRUE., .TRUE., 'B3FAC', PROGNAME )

C.......   Open gridded landuse files 

        GNAMET = PROMPTMFILE(
     &           'Enter logical name for GRIDDED LANDUSE totals file',
     &           FSREAD3, 'BELD3_TOT', PROGNAME )

        IF ( .NOT. DESC3( GNAMET ) ) THEN

            MESG = 'Could not get description of file "' //
     &             GNAMET( 1:TRIMLEN( GNAMET ) ) // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ENDIF

C.......   Initialize grid definition

        CALL CHKGRID( GNAMET, 'GRID' , 0, EFLAG )

        GNAME1 = PROMPTMFILE(
     &           'Enter logical name for GRIDDED LANDUSE A file',
     &           FSREAD3, 'BELD3_A', PROGNAME )

        IF ( .NOT. DESC3( GNAME1 ) ) THEN

            MESG = 'Could not get description of file "' //
     &             GNAME1( 1:TRIMLEN( GNAME1 ) ) // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ENDIF

C.......   Check grid definition

        CALL CHKGRID( GNAME1, 'GRID' , 0, EFLAG )

C........  If grid definition does not match first landuse file then stop

        IF ( EFLAG ) THEN
            MESG = 'Problems opening input files. See ERROR(S) above.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ENDIF

        NVARSA = NVARS3D

C.......   Grid cell resolution assumed to be in meters
C.......   Input land use will be in percentages
C.......   Compute conversion factor to go from percentages
C.......   to km**2

        NCOLS = NCOLS3D
        NROWS = NROWS3D
 
        PRCNT2KM2 = XCELL3D * YCELL3D * 1E-08

        ALLOCATE( LUNAMA( NVARSA ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LUNAMA', PROGNAME )

        DO I = 1, NVARSA

            LUNAMA ( I ) = VNAME3D ( I ) 

        ENDDO
 
        GNAME2 = PROMPTMFILE(
     &           'Enter logical name for GRIDDED LANDUSE B file',
     &           FSREAD3, 'BELD3_B', PROGNAME )

        IF ( .NOT. DESC3( GNAME2 ) ) THEN

            MESG = 'Could not get description of file "' //
     &             GNAME2( 1:TRIMLEN( GNAME2 ) ) // '"'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ENDIF

C.......   Check grid definition

        CALL CHKGRID( GNAME2, 'GRID' , 0, EFLAG )

C........  If grid definition does not match first landuse file then stop

        IF ( EFLAG ) THEN
            MESG = 'Problems opening input files. See ERROR(S) above.'
            CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ENDIF

        NVARSB = NVARS3D

        ALLOCATE( LUNAMB( NVARSB ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LUNAMB', PROGNAME )

        DO I = 1, NVARSB

            LUNAMB ( I ) = VNAME3D ( I ) 

        ENDDO

C............. set up header variables for output file B3GRD

        NROWS3D = NROWS
        NCOLS3D = NCOLS
        GDNAM3D = GRDNM
        FTYPE3D = GRDDED3

        SDATE3D = 0       !  n/a
        STIME3D = 0       !  n/a
        TSTEP3D = 0       !  time independent
        NVARS3D = BCATS * NSEASONS 
        NLAYS3D = 1
        NTHIK3D = 1
        VGTYP3D = IMISS3
        VGTOP3D = AMISS3

        FDESC3D = ' '   ! array

        FDESC3D( 1 ) = 'BEIS3 normalized emissions values.'
        FDESC3D( 2 ) = '/FROM/ '    // PROGNAME
        FDESC3D( 3 ) = '/VERSION/ ' // VERCHAR( CVSW )
        FDESC3D( 4 ) = '/LANDUSE/ SMOKE TOOL '

        I = 0

C.......... Setup variable names and output units

        DO  M = 1, NSEASONS 
          DO B = 1, BCATS

            BTMP = BIOTYPES( B ) 
            I = I + 1
            VNAME3D( I ) = 'AVG' // BTMP( 1: TRIMLEN( BTMP ))
     &                     // SEASON( M ) 
            VDESC3D( I ) = 'normalized emissions'
            IF ( BTMP( 1: TRIMLEN( BTMP ) ) .EQ. 'NO' ) THEN
               UNITS3D( I ) = 'gramsN/hour'
            ELSEIF ( BTMP( 1: TRIMLEN( BTMP ) ) .EQ. 'LAI' ) THEN
               UNITS3D( I ) = 'index'
            ELSE
               UNITS3D( I ) = 'gramsC/hour' 
            ENDIF
            VTYPE3D( I ) = M3REAL

          ENDDO
        ENDDO

C.......   Open output file

        ENAME = PROMPTMFILE(  
     &        'Enter logical name for NORMALIZED emissions output file',
     &        FSUNKN3, 'B3GRD', PROGNAME )

C.......  Get length of BFAC file

        NVEG = GETFLINE( FDEV, 'Emissions factor file' )

C.......  Allocate memory for emission factor variables   

        ALLOCATE( VEGID ( NVEG ), STAT=IOS )
        CALL CHECKMEM( IOS, 'VEGID', PROGNAME )

        ALLOCATE( EMFAC ( NVEG, NSEF ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EMFAC', PROGNAME )

        ALLOCATE( LAI ( NVEG ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LAI', PROGNAME )

        ALLOCATE( SLW ( NVEG ), STAT=IOS )
        CALL CHECKMEM( IOS, 'SLW', PROGNAME )

        ALLOCATE( WFAC ( NVEG ), STAT=IOS )
        CALL CHECKMEM( IOS, 'WFAC', PROGNAME )

        ALLOCATE( LFBIO ( NVEG ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LFBIO', PROGNAME )

C.......  Read emissions factor file

        WRITE( LDEV,92000 ) ' ', 'Reading EMISSIONS FACTOR file', ' '

        WRITE( LDEV, * )' Number of landuse types in factor file: ', 
     &                    NVEG

C........ This routine reads in emission factors 

        CALL RDB3FAC( FDEV, NVEG, VEGID, LAI, LFBIO, WFAC,
     &                SLW, EMFAC ) 

C........ Total number of land use types (should be 230)

        NVARST = NVARSA + NVARSB

        ALLOCATE( LUINDX ( NVARST ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LUINDX', PROGNAME )
        ALLOCATE( LUSE ( NCOLS, NROWS, NVEG ), STAT=IOS )
        CALL CHECKMEM( IOS, 'LUSE', PROGNAME )

        LUINDX = -9   ! array

C.......  Check to see if there are emissions factors for all landuse types

        DO I = 1, NVARST

           IFOUND = 0

           IF ( I .LE. NVARSA ) THEN
              LUNAM = LUNAMA( I ) 
           ELSE
              K = I - NVARSA
              LUNAM = LUNAMB( K ) 
           ENDIF 
 
           DO J = 1, NVEG

             IF ( VEGID ( J ) .EQ. LUNAM ) THEN
                IFOUND = 1  
                LUINDX( I ) = J
             ENDIF

C.........  Store vegids for certain USGS categories for use later

             IF ( VEGID( J ) .EQ. 'USGS_decidforest' ) IUSDEC = J
             IF ( VEGID( J ) .EQ. 'USGS_evbrdleaf  ' ) IUSBRD = J
             IF ( VEGID( J ) .EQ. 'USGS_coniferfor ' ) IUSCON = J
             IF ( VEGID( J ) .EQ. 'USGS_mxforest   ' ) IUSMIX = J
             IF ( VEGID( J ) .EQ. 'USGS_shrubland  ' ) IUSSHR = J

           ENDDO

           IF ( IFOUND .EQ. 0 ) THEN

               MESG =   LUNAM // 
     &                ' does NOT have emissions factors in BFAC file'
               CALL M3WARN( PROGNAME, 0, 0, MESG )

 
           ENDIF 
         
        ENDDO

C.......  Read the gridded landuse from the landuse files
       
        DO M = 1, NVARST 
     
          N = LUINDX ( M ) 

          IF ( N .GT. 0 ) THEN

            IF ( M .LE. NVARSA ) THEN
        
               MESG = ' Reading ' // LUNAMA( M )
               CALL M3MESG( MESG )
               IF( .NOT. READ3( GNAME1, LUNAMA( M ) , 1, 0, 0 , 
     &              LUSE( 1, 1, N ) ) ) THEN

                 MESG = 'Could not find ' // LUNAMA( M ) // 'in file '
     &                   // GNAME1( 1:TRIMLEN( GNAME1 ) )

                 CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

               ENDIF          !  if read3() failed

            ELSE

               K = M - NVARSA
               MESG = ' Reading ' // LUNAMB( K )
               CALL M3MESG( MESG )

               IF( .NOT. READ3( GNAME2, LUNAMB( K ) , 1, 0, 0 , 
     &              LUSE( 1, 1, N ) ) ) THEN

                 MESG = 'Could not find ' // LUNAMB( K ) // 'in file '
     &                   // GNAME2( 1:TRIMLEN( GNAME2 ) )

                 CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

               ENDIF          !  if read3() failed

            ENDIF

          ENDIF

        ENDDO

C.......  Allocate memory and read forest inventory data

        ALLOCATE( FIA( NCOLS, NROWS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'FIA', PROGNAME )

        IF ( .NOT. READ3( GNAMET, 'FOREST', 1, 0, 0, FIA ) ) THEN
             MESG = 'Could not read FOREST from file "' //
     &                GNAMET( 1:TRIMLEN( GNAMET ) ) // '"'
             CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        END IF

C.......   Allocate memory for output normalized fluxes

        ALLOCATE( AVGISOP( NCOLS, NROWS, NSEASONS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'AVGISOP', PROGNAME )
        ALLOCATE( AVGMONO( NCOLS, NROWS, NSEASONS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'AVGMONO', PROGNAME )
        ALLOCATE( AVGOVOC( NCOLS, NROWS, NSEASONS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'AVGOVOC', PROGNAME )
        ALLOCATE( AVGNO( NCOLS, NROWS, NSEASONS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'AVGNO', PROGNAME )
        ALLOCATE( AVGLAI( NCOLS, NROWS, NSEASONS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'AVGLAI', PROGNAME )

        AVGISOP = 0.0  !  array
        AVGMONO = 0.0  !  array
        AVGOVOC = 0.0  !  array
        AVGNO   = 0.0  !  array
        AVGLAI  = 0.0  !  array

C.......   Calculate normalized fluxes 

        DO I = 1, NCOLS
           DO J = 1, NROWS

C.......  Initialize variables

              SUMISOP = 0.0
              SUMISOPW = 0.0
              SUMOVOC = 0.0
              SUMOVOCW = 0.0
              SUMMONO = 0.0
              SUMMONOW = 0.0
              SUMNO = 0.0
              SUMNOW = 0.0
              SUMLAI = 0.0 
              SUMLAIW = 0.0

C.......   Sum USGS forest

              TOTFOR = LUSE( I, J, IUSDEC ) + LUSE( I, J, IUSBRD ) +
     &                 LUSE( I, J, IUSCON ) + LUSE( I, J, IUSMIX )
         
              DO M = 1, NVEG

C.......   Assuming that land use is in percentages
C.......   Converting to units of area (km**2)

                 VEGAREA = LUSE ( I, J, M ) * PRCNT2KM2    

                 EFISOP = EMFAC( M, 1 )
                 EFMONO = EMFAC( M, 2 )
                 EFOVOC = EMFAC( M, 3 )
                 EFNO   = EMFAC( M, 4 )

C........  If FIA and USGS data greater than 0, then use shrubland factors

                 IF ( TOTFOR .GT. 0.000 .AND. FIA( I, J ) .GT. 0 ) THEN

                    IF ( M .EQ. IUSDEC .OR. M .EQ. IUSBRD .OR.
     &                   M .EQ. IUSCON .OR. M .EQ. IUSMIX ) THEN

                      EFISOP = EMFAC( IUSSHR, 1 )
                      EFMONO = EMFAC( IUSSHR, 2 )
                      EFOVOC = EMFAC( IUSSHR, 3 )
                      EFNO   = EMFAC( IUSSHR, 4 )
                  
                    ENDIF

                 ENDIF

                 IF ( VEGAREA .GT. 0.0000 ) THEN

C........... Compute summer emissions

                   SUMISOP = SUMISOP + VEGAREA * EFISOP
                   SUMMONO = SUMMONO + VEGAREA * EFMONO
                   SUMOVOC = SUMOVOC + VEGAREA * EFOVOC
                   SUMNO  = SUMNO   + VEGAREA * EFNO
                   SUMLAI = SUMLAI  + VEGAREA * LAI( M ) * EFISOP

C........... Compute winter emissions

                   SUMISOPW = SUMISOPW + VEGAREA * EFISOP 
     &                        * WFAC( M )
                   SUMMONOW = SUMMONOW + VEGAREA * EFMONO 
     &                        * WFAC( M ) 
                   SUMOVOCW = SUMOVOCW  + VEGAREA * EFOVOC 
     &                        * WFAC( M )
                   SUMNOW   = SUMNOW  + VEGAREA * EFNO 
     &                        * WFAC( M )
                   SUMLAIW  = SUMLAIW + VEGAREA * LAI( M ) * 
     &                        EFISOP * WFAC( M )

                 ENDIF

              ENDDO    ! end of veg land use loop


              IF ( SUMLAI .LE. 1E-06 ) THEN
                AVGLAI( I, J, 1 ) = 0.0000
              ELSE IF ( SUMISOP .EQ. 0.0000 ) THEN
                AVGLAI( I, J, 1 ) = 0.0000 
              ELSE
                AVGLAI( I, J, 1 ) = SUMLAI/SUMISOP 
              ENDIF
     
              IF ( SUMLAIW .LE. 1E-06 ) THEN
                AVGLAI( I, J, 2) = 0.0000
              ELSE IF ( SUMISOPW .EQ. 0.0000 ) THEN
                AVGLAI( I, J, 2 ) = 0.0000 
              ELSE
                AVGLAI( I, J, 2) = SUMLAIW/SUMISOPW 
              ENDIF

              AVGISOP( I, J, 1 ) = SUMISOP
              AVGISOP( I, J, 2 ) = SUMISOPW
              AVGMONO( I, J, 1 ) = SUMMONO
              AVGMONO( I, J, 2 ) = SUMMONOW
              AVGOVOC( I, J, 1 ) = SUMOVOC
              AVGOVOC( I, J, 2 ) = SUMOVOCW
              AVGNO( I, J, 1 ) = SUMNO
              AVGNO( I, J, 2 ) = SUMNOW

           ENDDO

        ENDDO

C...............   Write output file:

        I = 0
        DO M = 1, NSEASONS

           I = I + 1
           IF ( .NOT. WRITE3( ENAME, VNAME3D( I ), 0, 0,
     &                         AVGISOP(1, 1, M ) ) ) THEN
              MESG = 'Could not write "' //
     &                  VNAME3D( I )( 1: TRIMLEN( VNAME3D( I ) ) ) //
     &                  '" to ' // ENAME
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
           ENDIF

           I = I + 1
           IF ( .NOT. WRITE3( ENAME, VNAME3D( I ), 0, 0,
     &                         AVGMONO( 1, 1, M ) ) ) THEN
              MESG = 'Could not write "' //
     &                  VNAME3D( I )( 1: TRIMLEN( VNAME3D( I ) ) ) //
     &                  '" to ' // ENAME
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
           ENDIF

           I = I + 1
           IF ( .NOT. WRITE3( ENAME, VNAME3D( I ), 0, 0,
     &                         AVGOVOC( 1, 1, M ) ) ) THEN
              MESG = 'Could not write "' //
     &                  VNAME3D( I )( 1: TRIMLEN( VNAME3D( I ) ) ) //
     &                  '" to ' // ENAME
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
           ENDIF

           I = I + 1
           IF ( .NOT. WRITE3( ENAME, VNAME3D( I ), 0, 0,
     &                         AVGNO( 1, 1, M ) ) ) THEN
              MESG = 'Could not write "' //
     &                  VNAME3D( I )( 1: TRIMLEN( VNAME3D( I ) ) ) //
     &                  '" to ' // ENAME
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
           ENDIF

           I = I + 1
           IF ( .NOT. WRITE3( ENAME, VNAME3D( I ), 0, 0,
     &                         AVGLAI( 1, 1, M ) ) ) THEN
              MESG = 'Could not write "' //
     &                  VNAME3D( I )( 1: TRIMLEN( VNAME3D( I ) ) ) //
     &                  '" to ' // ENAME
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
           ENDIF
 

        ENDDO

C.........   End of program:

        CALL M3EXIT( PROGNAME, 0, 0, ' ', 0 )

C******************  FORMAT  STATEMENTS   ******************************

C...........   Informational (LOG) message formats... 92xxx

92000   FORMAT ( 5X , A )

C...........   Formatted file I/O formats............ 93xxx
                                   
93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx
94010   FORMAT( 10 ( A, :, I5, :, 2X ) )

        END PROGRAM  NORMBEIS3 

