/* 
 * Filename : Call.xs
 * 
 * Author   : Paul Marquess 
 * Date     : 15th December 1995
 * Version  : 1.04
 *
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


/* Internal defines */
#define PERL_MODULE(s)		IoBOTTOM_NAME(s)
#define PERL_OBJECT(s)		IoTOP_GV(s)
#define FILTER_ACTIVE(s)	IoLINES(s)
#define BUF_OFFSET(sv)  	IoPAGE_LEN(sv)
#define CODE_REF(sv)  		IoFLAGS(sv)

#define SET_LEN(sv,len) \
        do { SvPVX(sv)[len] = '\0'; SvCUR_set(sv, len); } while (0)



static int fdebug = 0;
static int current_idx ;

static I32
filter_call(idx, buf_sv, maxlen)
    int idx;
    SV *buf_sv;
    int maxlen;
{
    SV   *my_sv = FILTER_DATA(idx);
    char *nl = "\n";
    char *p;
    char *out_ptr;
    int n;

    if (fdebug)
	warn("**** In filter_call - maxlen = %d, out len buf = %d idx = %d my_sv = %d [%s]\n", 
		maxlen, SvCUR(buf_sv), idx, SvCUR(my_sv), SvPVX(my_sv) ) ;

    while (1) {

	/* anything left from last time */
	if (n = SvCUR(my_sv)) {

	    out_ptr = SvPVX(my_sv) + BUF_OFFSET(my_sv) ;

	    if (maxlen) { 
		/* want a block */ 
		if (fdebug)
		    warn("BLOCK(%d): size = %d, maxlen = %d\n", 
			idx, n, maxlen) ;

	        sv_catpvn(buf_sv, out_ptr, maxlen > n ? n : maxlen );
		if(n <= maxlen) {
		    BUF_OFFSET(my_sv) = 0 ;
	            SET_LEN(my_sv, 0) ;
		}
		else {
		    BUF_OFFSET(my_sv) += maxlen ;
	            SvCUR_set(my_sv, n - maxlen) ;
		}
	        return SvCUR(buf_sv);
	    }
	    else {
		/* want lines */
                if (p = ninstr(out_ptr, out_ptr + n - 1, nl, nl)) {

	            sv_catpvn(buf_sv, out_ptr, p - out_ptr + 1);

	            n = n - (p - out_ptr + 1);
		    BUF_OFFSET(my_sv) += (p - out_ptr + 1);
	            SvCUR_set(my_sv, n) ;
	            if (fdebug)
		        warn("recycle %d - leaving %d, returning %d [%s]", 
				idx, n, SvCUR(buf_sv), SvPVX(buf_sv)) ;

	            return SvCUR(buf_sv);
	        }
	        else /* no EOL, so append the complete buffer */
	            sv_catpvn(buf_sv, out_ptr, n) ;
	    }
	    
	}


	SET_LEN(my_sv, 0) ;
	BUF_OFFSET(my_sv) = 0 ;

	if (FILTER_ACTIVE(my_sv))
	{
    	    dSP ;
    	    int count ;

            if (fdebug)
		warn("gonna call %s::filter\n", PERL_MODULE(my_sv)) ;

    	    ENTER ;
    	    SAVETMPS;
	
	    SAVEINT(current_idx) ; 	/* save current idx */
	    current_idx = idx ;

	    SAVESPTR(GvSV(defgv)) ;	/* save $_ */
	    /* make $_ use our buffer */
	    GvSV(defgv) = sv_2mortal(newSVpv("", 0)) ; 

    	    PUSHMARK(sp) ;

	    if (CODE_REF(my_sv)) {
    	        count = perl_call_sv((SV*)PERL_OBJECT(my_sv), G_SCALAR);
	    }
	    else {
                XPUSHs((SV*)PERL_OBJECT(my_sv)) ;  
	
    	        PUTBACK ;

    	        count = perl_call_method("filter", G_SCALAR);
	    }

    	    SPAGAIN ;

            if (count != 1)
	        croak("Filter::Util::Call - %s::filter returned %d values, 1 was expected \n", 
			PERL_MODULE(my_sv), count ) ;
    
	    n = POPi ;

	    if (fdebug)
	        warn("status = %d, length op buf = %d [%s]\n",
		     n, SvCUR(GvSV(defgv)), SvPVX(GvSV(defgv)) ) ;
	    if (SvCUR(GvSV(defgv)))
	        sv_setpvn(my_sv, SvPVX(GvSV(defgv)), SvCUR(GvSV(defgv))) ; 

    	    PUTBACK ;
    	    FREETMPS ;
    	    LEAVE ;
	}
	else
	    n = FILTER_READ(idx + 1, my_sv, maxlen) ;

 	if (n <= 0)
	{
	    /* Either EOF or an error */

	    if (fdebug) 
	        warn ("filter_read %d returned %d , returning %d\n", idx, n,
	            (SvCUR(buf_sv)>0) ? SvCUR(buf_sv) : n);

	    /* PERL_MODULE(my_sv) ; */
	    /* PERL_OBJECT(my_sv) ; */
	    filter_del(filter_call); 

	    /* If error, return the code */
	    if (n < 0)
		return n ;

	    /* return what we have so far else signal eof */
	    return (SvCUR(buf_sv)>0) ? SvCUR(buf_sv) : n;
	}

    }
}



MODULE = Filter::Util::Call		PACKAGE = Filter::Util::Call

REQUIRE:	1.924
PROTOTYPES:	ENABLE

#define IDX		current_idx

int
filter_read(size=0)
	int	size 
	CODE:
	{
	    SV * buffer = GvSV(defgv) ;

	    RETVAL = FILTER_READ(IDX + 1, buffer, size) ;
	}
	OUTPUT:
	    RETVAL




void
real_import(object, perlmodule, coderef)
    SV *	object
    char *	perlmodule 
    int		coderef
    PPCODE:
    {
        SV * sv = newSV(1) ;

        (void)SvPOK_only(sv) ;
        filter_add(filter_call, sv) ;

	PERL_MODULE(sv) = savepv(perlmodule) ;
	PERL_OBJECT(sv) = (GV*) newSVsv(object) ;
	FILTER_ACTIVE(sv) = TRUE ;
        BUF_OFFSET(sv) = 0 ;
	CODE_REF(sv)   = coderef ;

        SvCUR_set(sv, 0) ;

    }

void
filter_del()
    CODE:
	FILTER_ACTIVE(FILTER_DATA(IDX)) = FALSE ;



void
unimport(...)
    PPCODE:
    filter_del(filter_call);


BOOT:
    /* temporary hack to control debugging in toke.c */
    if (fdebug)
        filter_add(NULL, (fdebug) ? (SV*)"1" : (SV*)"0");  


