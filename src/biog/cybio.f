       SUBROUTINE  CYBIO ( UDEV, NGRID )

C***********************************************************************
C  subroutine body starts at line 152
C
C  DESCRIPTION:
C       Computes normalized gridded biogenic emissions in terms of
C       county level biomass, land use, emissions factors, and
C       surrogate factors.  The FIPS codes to use from the county
C       level biomass file are obtained from the surrogate factors
C       file.
C
C  SUBROUTINES AND FUNCTIONS CALLED:
C
C  REVISION  HISTORY:
C       02/00 : taken from RAWBIO and converted to a subroutine for 
C               better organization  JMV
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
C*************************************************************************

C...........   MODULES for public variables

C...........   This module contains the gridding surrogates tables

        USE MODSURG, ONLY: NSRGS, SRGLIST, NSRGFIPS, SRGFIPS, SRGFRAC,
     &                     NCELLS, FIPCELL
        
C...........   This module contains the biogenic variables

        USE MODBIOG, ONLY: NVEG, VEGID, PINE, DECD, CONF, AGRC, LEAF,
     &                     OTHR, GRASNO, FORENO, WETLNO, AGRINO, 
     &                     AVLAI, LAI, EMFAC

        IMPLICIT NONE

        INCLUDE 'EMCNST3.EXT'     ! emissions constants
        INCLUDE 'BIODIMS3.EXT'    ! biogenic-related constants

C...........   EXTERNAL FUNCTIONS and their descriptions:

        INTEGER         ENVINT
        INTEGER         FIND1
        INTEGER         GETFLINE
        INTEGER         INDEX1
        INTEGER         LBLANK
        INTEGER         STR2INT
        REAL            STR2REAL

        EXTERNAL        ENVINT, FIND1, GETFLINE, INDEX1, LBLANK,
     &                  STR2INT, STR2REAL

        INTEGER, INTENT (IN)  ::  UDEV    !  unit number for county landuse file
        INTEGER, INTENT (IN)  ::  NGRID   !  total no. of cells in grid  

C.......   Source-level variables

        REAL    EMIS, AFOR, ENOFOR    
        REAL    AAG, ENOAG, ENOGRS, ENOWTF

        REAL, ALLOCATABLE :: EOTH ( : )   ! other landuse
        REAL, ALLOCATABLE :: EPINE( : )   ! pine
        REAL, ALLOCATABLE :: EDECD( : )   ! deciduous
        REAL, ALLOCATABLE :: ECONF( : )   ! coniferous
        REAL, ALLOCATABLE :: EAG  ( : )   ! agriculture
        REAL, ALLOCATABLE :: ELAI ( : )   ! leaf area index

        REAL    AOTH, AGRS, AWTF, ALAI, SUMLAI, AVGLAI

C.......   County-level variables:

        REAL, ALLOCATABLE :: CTYPINE( : , : )
        REAL, ALLOCATABLE :: CTYDECD( : , : )
        REAL, ALLOCATABLE :: CTYCONF( : , : )
        REAL, ALLOCATABLE :: CTYAGRI( : , : )
        REAL, ALLOCATABLE :: CTYLEAF( : , : )
        REAL, ALLOCATABLE :: CTYOTHR( : , : )
        REAL, ALLOCATABLE :: CTYNOFOR( : )
        REAL, ALLOCATABLE :: CTYNOGRS( : )
        REAL, ALLOCATABLE :: CTYNOAG ( : )
        REAL, ALLOCATABLE :: CTYNOWTF( : )
        REAL, ALLOCATABLE :: CTYAVLAI( : )
        REAL, ALLOCATABLE :: CTYAFOR ( : )
        REAL, ALLOCATABLE :: CTYAAG  ( : )
        REAL, ALLOCATABLE :: CTYAGRS ( : )
        REAL, ALLOCATABLE :: CTYAWTF ( : )
        REAL, ALLOCATABLE :: CTYAOTH ( : )

C.......   Surrogate indices

        INTEGER         PSRG    !  for pine forest
        INTEGER         DSRG    !  for deciduous forest
        INTEGER         CSRG    !  for coniferous nonpine forest
        INTEGER         ASRG    !  for agriculture
        INTEGER         OSRG    !  for other land uses
        INTEGER         FSRG    !  for forest
        INTEGER         GSRG    !  for grasslands
        INTEGER         WSRG    !  for grasslands
        INTEGER         ARSRG   !  for leaf area index

        INTEGER         PSRGC    !  for pine forest surrogate code
        INTEGER         DSRGC    !  for deciduous forest surrogate code
        INTEGER         CSRGC    !  for coniferous nonpine forest surrogate code
        INTEGER         ASRGC    !  for agriculturt surrogate code
        INTEGER         OSRGC    !  for other land uset surrogate code
        INTEGER         FSRGC    !  for forest surrogate code
        INTEGER         GSRGC    !  for grasslandt surrogate code
        INTEGER         WSRGC    !  for grasslandt surrogate code
        INTEGER         ARSRGC   !  for leaf area indet surrogate code

        INTEGER         NLINE   !  Line number counter for BCUSE
        INTEGER         FLINES  !  Number of lines in BCUSE
        INTEGER         FIP     !  fip code
        INTEGER         CTY     !  subscript into FIPS table

        INTEGER         B, C, R, I, J, K, L, M, N ! loop counters and subscripts

        INTEGER         IOS     !  I/O status result

        REAL            AREA    !  land-use area
        REAL            ATYPE   !  area for this land use type
        INTEGER         NTYPE   !  number of land use types
        CHARACTER*4     TYPE    !  land use type
        CHARACTER*80    INBUF   !  input buffer
        CHARACTER*256   MESG    !  message buffer for M3EXIT()

        LOGICAL         EFLAG   !  error flag

        CHARACTER*16 :: PROGNAME = 'CYBIO'   !  program name

C***********************************************************************
C   begin body of subroutine  CYBIO

C.......   Get surrogate categories for each emissions type:

        MESG = 'Pine surrogate code '
        PSRGC = ENVINT( 'PINE_SURG', MESG, 60, IOS )

        K = FIND1( PSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', PSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           PSRG =  K

        ENDIF

        MESG = 'Deciduous surrogate code '
        DSRGC = ENVINT( 'DECD_SURG', MESG, 60, IOS )

        K = FIND1( DSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

             WRITE( MESG,94010 )
     &       'Surrogate code ', DSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           DSRG =  K

        ENDIF


        MESG = 'Coniferous surrogate code '
        CSRGC = ENVINT( 'CONF_SURG', MESG, 60, IOS )

        K = FIND1( CSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )

     &       'Surrogate code ', CSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           CSRG =  K

        ENDIF

        MESG = 'All forest surrogate code '
        FSRGC = ENVINT( 'ALLFOR_SURG', MESG, 60, IOS )

        K = FIND1( FSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', FSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           FSRG =  K

        ENDIF

        MESG = 'Agriculture surrogate code '
        ASRGC = ENVINT( 'AGRI_SURG', MESG, 60, IOS )

        K = FIND1( ASRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', ASRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           ASRG =  K

        ENDIF

        MESG = 'Grasslands surrogate code '
        GSRGC = ENVINT( 'GRASS_SURG', MESG, 60, IOS )

        K = FIND1( GSRGC, NSRGS, SRGLIST )


        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', GSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           GSRG =  K

        ENDIF

        MESG = 'Wetlands surrogate code '
        WSRGC = ENVINT( 'WETL_SURG', MESG, 60, IOS )

        K = FIND1( WSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', WSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )

        ELSE

           WSRG =  K

        ENDIF

        MESG = 'Other land uses surrogate code '
        OSRGC = ENVINT( 'OTHER_SURG', MESG, 60, IOS )

        K = FIND1( OSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', OSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

           OSRG =  K

        ENDIF

        MESG = 'Leaf area index surrogate code '
        ARSRGC = ENVINT( 'LAI_SURG', MESG, 60, IOS )

        K = FIND1( ARSRGC, NSRGS, SRGLIST )

        IF ( K .LT. 0 ) THEN

           WRITE( MESG,94010 )
     &       'Surrogate code ', ARSRGC, ' not found in surrogates '
              CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
        ELSE

          ARSRG =  K

        ENDIF



C.......   Allocate memory for reading and storing county land use

        ALLOCATE( EPINE ( BSPCS-1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EPINE', PROGNAME )
        ALLOCATE( EDECD ( BSPCS-1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EDECD', PROGNAME )
        ALLOCATE( ECONF ( BSPCS-1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ECONF', PROGNAME )
        ALLOCATE( EOTH ( BSPCS-1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EOTH', PROGNAME )
        ALLOCATE( ELAI ( BSPCS-1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'ELAI', PROGNAME )
        ALLOCATE( EAG ( BSPCS-1 ), STAT=IOS )
        CALL CHECKMEM( IOS, 'EAG', PROGNAME )

        ALLOCATE( CTYPINE ( BSPCS-1, NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYPINE', PROGNAME )
        ALLOCATE( CTYDECD ( BSPCS-1, NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYDECD', PROGNAME )
        ALLOCATE( CTYCONF ( BSPCS-1, NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYCONF', PROGNAME )
        ALLOCATE( CTYAGRI ( BSPCS-1, NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAGRI', PROGNAME )
        ALLOCATE( CTYLEAF ( BSPCS-1, NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYLEAF', PROGNAME )
        ALLOCATE( CTYOTHR ( BSPCS-1, NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYOTHR', PROGNAME )

        ALLOCATE( CTYNOFOR ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYNOFOR', PROGNAME )
        ALLOCATE( CTYNOGRS ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYNOGRS', PROGNAME )
        ALLOCATE( CTYNOAG ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYNOAG', PROGNAME )
        ALLOCATE( CTYNOWTF ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYNOWTF', PROGNAME )
        ALLOCATE( CTYAVLAI ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAVLAI', PROGNAME )
        ALLOCATE( CTYAFOR ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAFOR', PROGNAME )
        ALLOCATE( CTYAAG ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAAG', PROGNAME )
        ALLOCATE( CTYAGRS ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAGRS', PROGNAME )
        ALLOCATE( CTYAWTF ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAWTF', PROGNAME )
        ALLOCATE( CTYAOTH ( NSRGFIPS ), STAT=IOS )
        CALL CHECKMEM( IOS, 'CTYAOTH', PROGNAME )


        CTYPINE = 0.   ! array
        CTYDECD = 0.   ! array
        CTYCONF = 0.   ! array
        CTYAGRI = 0.   ! array
        CTYLEAF = 0.   ! array
        CTYOTHR = 0.   ! array
        CTYNOFOR = 0.  ! array
        CTYNOGRS = 0.  ! array
        CTYNOAG =  0.  ! array
        CTYNOWTF = 0.  ! array
        CTYAVLAI = 0.  ! array
        CTYAFOR =  0.  ! array
        CTYAAG =  0.   ! array
        CTYAGRS = 0.   ! array
        CTYAWTF = 0.   ! array
        CTYAOTH = 0.   ! array
         
C.......   Loop:  read county land use file:

        WRITE( MESG, 93000 ) 'Reading COUNTY LAND USE file'
        CALL M3MSG2( MESG )

C.......  Get length of BCUSE file

        FLINES = GETFLINE( UDEV, ' County land use file' )  

        EFLAG = .FALSE.

        NLINE = 0

C....... Read until end of the BCUSE file

        DO WHILE ( NLINE .LT. FLINES )  

            READ( UDEV, 93000, IOSTAT=IOS ) INBUF
            NLINE = NLINE + 1
            IF ( IOS .NE. 0 ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &          'Error reading FIP from COUNTY LAND USE at line', NLINE
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

C..........  Check to see if FIP is in the surrogates file BGPRO

            FIP = STR2INT( INBUF )
            CTY = FIND1( FIP, NSRGFIPS, SRGFIPS )

C...........   Initialize accumulator variables for this county:


            EPINE = 0.0    ! array
            EDECD = 0.0    ! array
            ECONF = 0.0    ! array
            EOTH  = 0.0    ! array 
            ELAI  = 0.0    ! array 
            EAG   = 0.0    ! array

            AFOR   = 0.0
            AAG    = 0.0
            AGRS   = 0.0
            AWTF   = 0.0
            AOTH   = 0.0
            ALAI   = 0.0
            ENOFOR = 0.0
            ENOAG  = 0.0
            ENOGRS = 0.0
            ENOWTF = 0.0
            SUMLAI = 0.0


C...........   Land use type:  (rural) forest.  Process subtypes:

            READ( UDEV, 93000, IOSTAT=IOS ) INBUF
            NLINE = NLINE + 1
            IF ( IOS .NE. 0 ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &          'Error reading FOREST AREA from ' //
     &          'COUNTY LAND USE at line', NLINE
                CALL M3EXIT( PROGNAME , 0, 0, MESG, 2 )
            END IF

            I     = INDEX( INBUF, ',' )
            ATYPE = STR2REAL( INBUF(   1 : I-1 ) )
            NTYPE = STR2INT ( INBUF( I+1 :  80 ) )

            DO  N = 1, NTYPE

                READ( UDEV, 93000, IOSTAT=IOS ) INBUF
                NLINE =  NLINE + 1
                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &              'Error reading AREA TYPE from ' //
     &              'COUNTY LAND USE at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                J     = LBLANK( INBUF )
                I     = INDEX( INBUF( J+1:80 ) , ',' )
                TYPE  = INBUF( J+1 : J+I-1 )
                AREA  = STR2REAL( INBUF( J+I+1 : 80 ) )
                K     = INDEX1( TYPE, NVEG, VEGID )

                IF ( K .EQ. 0 ) THEN
                    WRITE( MESG,94010 ) 
     &              'Could not find "' // TYPE // 
     &              '" from LU FILE in VEGID at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                L = INDEX1( TYPE, SPTREE, SPFORID )

                IF ( L .GT. 0 ) THEN
                    AFOR   = AFOR   + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    ALAI   = ALAI   + AREA
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOFOR = ENOFOR + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Wdcp' ) THEN

                    AFOR   = AFOR   + 0.5*AREA
                    AAG    = AAG    + 0.5*AREA
                    ALAI   = ALAI   + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOAG  = ENOAG + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Scwd' ) THEN

                    AFOR   = AFOR   + 0.5*AREA
                    AGRS   = AAG    + 0.5*AREA
                    ALAI   = ALAI   + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Urba' ) THEN

                    AFOR   = AFOR   + 0.2*AREA
                    AGRS   = AAG    + 0.2*AREA
                    AOTH   = AAG    + 0.6*AREA
                    DO  M = 1, BSPCS - 1
                        EOTH( M ) = EOTH( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE    !  Add area to the forest area, add NO to the forest NO

                    AFOR = AFOR + AREA
                    ENOFOR = ENOFOR + AREA * EMFAC( K, NO )

                    IF     ( LAI( K ) .EQ. 3 ) THEN
                        DO  M = 1, BSPCS - 1
                            EPINE( M ) = EPINE( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    ELSE IF( LAI( K ) .EQ. 5 ) THEN

                        DO  M = 1, BSPCS - 1
                            EDECD( M ) = EDECD( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    ELSE IF( LAI( K ) .EQ. 7 ) THEN

                        DO  M = 1, BSPCS - 1
                            ECONF( M ) = ECONF( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    ELSE

                        SUMLAI = SUMLAI + AREA * LAI( K )
                        ALAI   = ALAI   + AREA
                        DO  M = 1, BSPCS - 1
                            ELAI( M ) = ELAI( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    END IF      !  if lai is 3,5,7, or otherwise

                END IF  !  if some spforid, or 'Wdcp' or 'Scwd' or 'Urba or not

            ENDDO


C...........   Land use type:  urban forest.  Process subtypes:

            READ( UDEV, 93000, IOSTAT=IOS ) INBUF
            NLINE =  NLINE + 1
            IF ( IOS .NE. 0 ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &          'Error reading URBAN FOREST from ' //
     &          'COUNTY LAND USE at line', NLINE
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

            I     = INDEX( INBUF, ',' )
            ATYPE = STR2REAL( INBUF(   1 : I-1 ) )
            NTYPE = STR2INT ( INBUF( I+1 :  80 ) )

            DO  N = 1, NTYPE

                READ( UDEV, 93000, IOSTAT=IOS ) INBUF
                NLINE =  NLINE + 1
                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &              'Error reading AREA TYPE from ' //
     &              'COUNTY LAND USE at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                J     = LBLANK( INBUF )
                I     = INDEX( INBUF( J+1:80 ) , ',' )
                TYPE  = INBUF( J+1 : J+I-1 )
                AREA  = STR2REAL( INBUF( J+I+1 : 80 ) )

                K     = INDEX1( TYPE, NVEG, VEGID )

                IF ( K .EQ. 0 ) THEN
                    WRITE( MESG,94010 ) 
     &              'Could not find "' // TYPE // 
     &              '" from LU FILE in VEGID at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                L = INDEX1( TYPE, SPTREE, SPFORID )

                IF ( L .GT. 0 ) THEN

                    AFOR   = AFOR   + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    ALAI   = ALAI   + AREA
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOFOR = ENOFOR + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Wdcp' ) THEN

                    AFOR   = AFOR   + 0.5*AREA
                    AAG    = AAG    + 0.5*AREA
                    ALAI   = ALAI   + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOAG  = ENOAG + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Scwd' ) THEN

                    AFOR   = AFOR   + 0.5*AREA
                    AGRS   = AAG    + 0.5*AREA
                    ALAI   = ALAI   + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Urba' ) THEN

                    AFOR   = AFOR   + 0.2*AREA
                    AGRS   = AAG    + 0.2*AREA
                    AOTH   = AAG    + 0.6*AREA
                    DO  M = 1, BSPCS - 1
                        EOTH( M ) = EOTH( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE    !  Add area to the forest area, add NO to the forest NO

                    AFOR = AFOR + AREA
                    ENOFOR = ENOFOR + AREA * EMFAC( K, NO )

                    IF     ( LAI( K ) .EQ. 3 ) THEN
                        DO  M = 1, BSPCS - 1
                            EPINE( M ) = EPINE( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    ELSE IF( LAI( K ) .EQ. 5 ) THEN

                        DO  M = 1, BSPCS - 1
                            EDECD( M ) = EDECD( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    ELSE IF( LAI( K ) .EQ. 7 ) THEN

                        DO  M = 1, BSPCS - 1
                            ECONF( M ) = ECONF( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    ELSE

                        SUMLAI = SUMLAI + AREA * LAI( K )
                        ALAI   = ALAI   + AREA
                        DO  M = 1, BSPCS - 1
                            ELAI( M ) = ELAI( M ) + AREA*EMFAC( K,M )
                        ENDDO

                    END IF      !!  if lai is 3,5,7, or otherwise

                END IF  !  if some spforid, or 'Wdcp' or 'Scwd' or 'Urba or not

            ENDDO


C...........   Land use type:  agriculture.  Process subtypes:

            READ( UDEV, 93000, IOSTAT=IOS ) INBUF
            NLINE =  NLINE + 1
            IF ( IOS .NE. 0 ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &          'Error reading AGRICULTURE from ' //
     &          'COUNTY LAND USE at line', NLINE
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

            I     = INDEX( INBUF, ',' )
            ATYPE = STR2REAL( INBUF(   1 : I-1 ) )
            NTYPE = STR2INT ( INBUF( I+1 :  80 ) )

            DO  N = 1, NTYPE

                READ( UDEV, 93000, IOSTAT=IOS ) INBUF
                NLINE =  NLINE + 1
                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &              'Error reading AREA TYPE from ' //
     &              'COUNTY LAND USE at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                J     = LBLANK( INBUF )
                I     = INDEX( INBUF( J+1:80 ) , ',' )
                TYPE  = INBUF( J+1 : J+I-1 )
                AREA  = STR2REAL( INBUF( J+I+1 : 80 ) )

                K     = INDEX1( TYPE, NVEG, VEGID )

                IF ( K .EQ. 0 ) THEN
                    WRITE( MESG,94010 ) 
     &              'Could not find "' // TYPE // 
     &              '" from LU FILE in VEGID at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                AAG = AAG + AREA
                DO  M = 1, BSPCS - 1
                    EAG( M ) = EAG( M ) + AREA * EMFAC( K , M )
                ENDDO
                ENOAG  = ENOAG + AREA * EMFAC( K, NO )

            ENDDO


C...........   Land use type:  remaining/other.  Process subtypes:

            READ( UDEV, 93000, IOSTAT=IOS ) INBUF
            NLINE =  NLINE + 1
            IF ( IOS .NE. 0 ) THEN
                EFLAG = .TRUE.
                WRITE( MESG,94010 ) 
     &          'Error reading OTHER AREA from ' //
     &          'COUNTY LAND USE at line', NLINE
                CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
            END IF

            I     = INDEX( INBUF, ',' )
            ATYPE = STR2REAL( INBUF(   1 : I-1 ) )
            NTYPE = STR2INT ( INBUF( I+1 :  80 ) )

            DO  N = 1, NTYPE

                READ( UDEV, 93000, IOSTAT=IOS ) INBUF
                NLINE =  NLINE + 1
                IF ( IOS .NE. 0 ) THEN
                    EFLAG = .TRUE.
                    WRITE( MESG,94010 ) 
     &              'Error reading AREA TYPE from ' //
     &              'COUNTY LAND USE at line', NLINE
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                J     = LBLANK( INBUF )
                I     = INDEX( INBUF( J+1:80 ) , ',' )
                TYPE  = INBUF( J+1 : J+I-1 )
                AREA  = STR2REAL( INBUF( J+I+1 : 80 ) )

                K     = INDEX1( TYPE, NVEG, VEGID )

                IF ( K .EQ. 0 ) THEN
                    WRITE( MESG,94010 ) 
     &              'Could not find "' // TYPE // 
     &              '" from LU FILE in VEGID at line', NLINE 
                    CALL M3EXIT( PROGNAME, 0, 0, MESG, 2 )
                END IF

                L = INDEX1( TYPE, RMTREE, OTHERID )

                IF ( L .GT. 0 ) THEN

                    ALAI   = ALAI + AREA
                    AFOR   = AFOR + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOFOR = ENOFOR + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Pacp' ) THEN

                    AAG = AAG + AREA
                    DO  M = 1, BSPCS - 1
                        EAG( M ) = EAG( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOAG = ENOAG + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Gras' .OR.

     &                    TYPE .EQ. 'Scru' .OR.
     &                    TYPE .EQ. 'Ugra' .OR.
     &                    TYPE .EQ. 'Othe' ) THEN
                    AGRS = AGRS + AREA
                    DO  M = 1, BSPCS - 1
                        EOTH( M ) = EOTH( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Wetf' ) THEN

                    AWTF = AWTF + AREA
                    ALAI = ALAI + AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        EMIS = AREA * EMFAC( K , M )
                        ELAI( M ) = ELAI( M ) + EMIS
                    ENDDO
                    ENOWTF = ENOWTF + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Wate' .OR.
     &                    TYPE .EQ. 'Barr' .OR.
     &                    TYPE .EQ. 'Uoth' ) THEN

                        AOTH = AOTH + AREA

                ELSE IF ( TYPE .EQ. 'Wdcp' ) THEN

                    ALAI   = ALAI   + AREA
                    AFOR   = AFOR   + 0.5 * AREA
                    AAG    = AAG    + 0.5 * AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOAG = ENOAG + AREA * EMFAC( K, NO )
                ELSE IF ( TYPE .EQ. 'Scwd' ) THEN
                    ALAI   = ALAI   + AREA
                    AFOR   = AFOR   + 0.5 * AREA
                    AGRS   = AGRS   + 0.5 * AREA
                    SUMLAI = SUMLAI + AREA * LAI( K )
                    DO  M = 1, BSPCS - 1
                        ELAI( M ) = ELAI( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Urba' ) THEN

                    AFOR   = AFOR   + 0.2 * AREA
                    AGRS   = AGRS   + 0.2 * AREA
                    AOTH   = AOTH   + 0.6 * AREA
                    DO  M = 1, BSPCS - 1
                        EOTH( M ) = EOTH( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE IF ( TYPE .EQ. 'Desh' ) THEN

                    AGRS   = AGRS   + 0.5 * AREA
                    AOTH   = AOTH   + 0.5 * AREA
                    DO  M = 1, BSPCS - 1
                        EOTH( M ) = EOTH( M ) + AREA * EMFAC( K , M )
                    ENDDO
                    ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                ELSE

                    AOTH = AOTH + AREA

                    IF ( LAI( K ) .GT. 0 ) THEN

                        ALAI   = ALAI   + AREA
                        SUMLAI = SUMLAI + AREA * LAI( K )
                        DO  M = 1, BSPCS - 1
                            ELAI( M ) = ELAI( M ) + AREA * EMFAC( K,M )
                        ENDDO
                        ENOFOR = ENOFOR + AREA * EMFAC( K, NO )

                    ELSE

                        DO  M = 1, BSPCS - 1
                            EOTH( M ) = EOTH( M ) + AREA * EMFAC( K,M )
                        ENDDO
                        ENOGRS = ENOGRS + AREA * EMFAC( K, NO )

                    END IF

                END IF

           ENDDO


C...........   Save only counties found in the surrogates file BGPRO

           IF ( CTY .GT. 0 ) THEN

               IF ( ALAI .GT. 0.0 ) THEN
                   AVGLAI = SUMLAI / ALAI 
               ELSE
                   AVGLAI = 0.0
               END IF

               DO  M = 1, BSPCS - 1

                   CTYPINE( M,CTY ) = EPINE( M )
                   CTYDECD( M,CTY ) = EDECD( M )
                   CTYCONF( M,CTY ) = ECONF( M )
                   CTYAGRI( M,CTY ) = EAG  ( M )
                   CTYLEAF( M,CTY ) = ELAI ( M )
                   CTYOTHR( M,CTY ) = EOTH ( M )

               ENDDO           

               CTYNOFOR( CTY ) = ENOFOR
               CTYNOGRS( CTY ) = ENOGRS
               CTYNOAG ( CTY ) = ENOAG
               CTYNOWTF( CTY ) = ENOWTF
               CTYAVLAI( CTY ) = AVGLAI
               CTYAFOR ( CTY ) = AFOR
               CTYAAG  ( CTY ) = AAG
               CTYAGRS ( CTY ) = AGRS
               CTYAWTF ( CTY ) = AWTF
               CTYAOTH ( CTY ) = AOTH

           END IF

        ENDDO

C........ Apply appropriate surrogate code fractions and calculate
C         gridded normalized emissions

        DO N = 1, NSRGFIPS

          DO R = 1, NCELLS(N)
            C = FIPCELL( R, N )
         
            DO  M = 1, BSPCS - 1
              PINE( C,M ) = PINE( C,M ) + 
     &                          CTYPINE( M,N ) * SRGFRAC( PSRG, R, N )
              DECD( C,M ) = DECD( C,M ) + 
     &                          CTYDECD( M,N ) * SRGFRAC( DSRG, R, N )
              CONF( C,M ) = CONF( C,M ) + 
     &                          CTYCONF( M,N ) * SRGFRAC( CSRG, R, N )
              AGRC( C,M ) = AGRC( C,M ) + 
     &                          CTYAGRI( M,N ) * SRGFRAC( ASRG, R, N )
              LEAF( C,M ) = LEAF( C,M ) +
     &                          CTYLEAF( M,N ) * SRGFRAC( ARSRG, R, N )
              OTHR( C,M ) = OTHR( C,M ) + 
     &                          CTYOTHR( M,N ) * SRGFRAC( OSRG, R, N )
            ENDDO
            GRASNO( C ) = GRASNO( C ) + CTYNOGRS( N ) * 
     &                          SRGFRAC( GSRG, R, N )
            FORENO( C ) = FORENO( C ) + CTYNOFOR( N ) * 
     &                          SRGFRAC( FSRG, R, N )
            WETLNO( C ) = WETLNO( C ) + CTYNOWTF( N ) * 
     &                          SRGFRAC( WSRG, R, N )
            AGRINO( C ) = AGRINO( C ) + CTYNOAG ( N ) * 
     &                          SRGFRAC( ASRG, R, N )
            AVLAI ( C ) = AVLAI ( C ) + CTYAVLAI( N ) * 
     &                          SRGFRAC( ARSRG, R, N )
          ENDDO
        ENDDO

        RETURN

C******************  FORMAT  STATEMENTS   ******************************

               
C...........   Formatted file I/O formats............ 93xxx

93000   FORMAT( A )

C...........   Internal buffering formats............ 94xxx
94010   FORMAT( 10 ( A, :, I5, :, 2X ) )

        END SUBROUTINE CYBIO
 
