#pragma once

#include <QtCore/qglobal.h>

#ifndef BUILD_STATIC
# if defined(ASSYPARTPARAMCHECK_LIB)
#  define ASSYPARTPARAMCHECK_EXPORT Q_DECL_EXPORT
# else
#  define ASSYPARTPARAMCHECK_EXPORT Q_DECL_IMPORT
# endif
#else
# define ASSYPARTPARAMCHECK_EXPORT
#endif
