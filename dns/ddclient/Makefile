PLUGIN_NAME=		ddclient
PLUGIN_VERSION=		1.32
PLUGIN_COMMENT=		Dynamic DNS client
PLUGIN_MAINTAINER=	ad@opnsense.org
PLUGIN_VARIANTS=	dyndns ddclient

dyndns_NAME=		dyndns
dyndns_DEPENDS=		py${PLUGIN_PYTHON}-boto3
dyndns_TIER=		2

ddclient_NAME=		ddclient
ddclient_DEPENDS=	ddclient
ddclient_TIER=		3

.include "../../Mk/plugins.mk"
