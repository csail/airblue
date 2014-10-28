#include <macaddr.h>

bool operator<(const mac_addr& lhs, const mac_addr& rhs) {

  return (lhs.Mac2String() < rhs.Mac2String());

}
