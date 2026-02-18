#include <stdint.h>

#define PCIE_TX_HEADER0      (*(volatile uint32_t*)(0x30000000))
#define PCIE_TX_HEADER1      (*(volatile uint32_t*)(0x30000004))
#define PCIE_TX_HEADER2      (*(volatile uint32_t*)(0x30000008))
#define PCIE_TX_DATA         (*(volatile uint32_t*)(0x3000000C))

#define PCIE_RX_STATUS       (*(volatile uint32_t*)(0x30000010)) 
#define PCIE_RX_DATA         (*(volatile uint32_t*)(0x30000014)) 
#define PCIE_RX_HEADER_INFO  (*(volatile uint32_t*)(0x30000018)) 
#define PCIE_ERR_STATUS      (*(volatile uint32_t*)(0x3000001C)) 
#define PCIE_PHY_STATUS      (*(volatile uint32_t*)(0x30000020)) 

#define MY_REQUESTER_ID  0x10EE 

#define TX_STATE_MASK 0xC0
#define TX_BUF_MASK   0x3F

#define TLP_CFG_WR0 0x44000000 
#define TLP_CFG_RD0 0x04000000 
#define TLP_MEM_WR  0x40000000 
#define TLP_MEM_RD  0x00000000 

#define CPL_STAT_SC  0 // Successful
#define CPL_STAT_UR  1 // Unsupported Request
#define CPL_STAT_CRS 2 // Configuration Retry Status (Busy)
#define CPL_STAT_CA  4 // Completer Abort

uint8_t tx_tag;

void wait_cycles(int n) {
    for (int i = 0; i < n; i++) __asm__("nop");
}

void send_tlp(uint32_t h0, uint32_t h1, uint32_t h2, uint32_t data) {
    while (((PCIE_PHY_STATUS & TX_STATE_MASK) != 0) || 
           ((PCIE_PHY_STATUS & TX_BUF_MASK) == 0));

    PCIE_TX_HEADER0 = h0;
    PCIE_TX_HEADER1 = h1;
    PCIE_TX_HEADER2 = h2;
    PCIE_TX_DATA = data;
}

uint32_t wait_for_completion(uint8_t tag) {
    volatile int timeout = 2000000;
    
    while (timeout > 0) {
        uint32_t raw_header = PCIE_RX_HEADER_INFO;
        uint16_t rx_req_id = (raw_header >> 16) & 0xFFFF;
        uint8_t  rx_tag    = (raw_header >> 8)  & 0xFF;

        if (rx_req_id == MY_REQUESTER_ID && rx_tag == tag) {
            if (PCIE_RX_STATUS == CPL_STAT_SC) {
                return PCIE_RX_DATA; 
            } else {
                return 0xFFFFFFFF; 
            }
        }
        timeout--;
    }
    return 0xFFFFFFFF; 
}

void pcie_cfg_write(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t val) {
    uint8_t tag = tx_tag++;
    uint32_t id = (bus << 24) | (dev << 19) | (func << 16) | (reg & 0xFC);
    
    send_tlp(TLP_CFG_WR0 | 0x01, 
             (MY_REQUESTER_ID << 16) | (tag << 8) | 0x0F, 
             id, val);

    wait_for_completion(tag);
}

void pcie_mem_write(uint32_t addr, uint32_t val) {
	uint8_t tag = tx_tag++;
	
    send_tlp(TLP_MEM_WR | 0x01,                           
             (MY_REQUESTER_ID << 16) | (tag << 8) | 0x0F, 
             addr & 0xFFFFFFFC,                          
             val);                                        
}

uint32_t pcie_read(uint32_t type, uint32_t addr_or_id) {
	
    for (int retry_count = 0; retry_count <= 100; retry_count++) {
        
        uint8_t current_tag = tx_tag++; 

		send_tlp(type | 0x01,                                  			
                 (MY_REQUESTER_ID << 16) | (current_tag << 8) | 0x0F,   
                 addr_or_id & 0xFFFFFFFC,                      			
                 0);                                           			

        volatile int timeout = 2000000;
        int crs_received = 0; 

        while (timeout > 0) {
            uint32_t raw_header = PCIE_RX_HEADER_INFO;
            uint16_t rx_req_id = (raw_header >> 16) & 0xFFFF;
            uint8_t  rx_tag    = (raw_header >> 8)  & 0xFF;

            if (rx_req_id == MY_REQUESTER_ID && rx_tag == current_tag) {
                uint32_t rx_status = PCIE_RX_STATUS; 
                
                if (rx_status == CPL_STAT_SC) { 
                    return PCIE_RX_DATA; 
                }
                
                if (rx_status == CPL_STAT_CRS) { 
                    wait_cycles(1000); 
                    crs_received = 1; 
                    break; 
                }

                return 0xFFFFFFFF;
            }
            timeout--;
        }

        if (!crs_received && timeout <= 0) {
            return 0xFFFFFFFF; 
        }
    }

    return 0xFFFFFFFF;
}

uint32_t pcie_cfg_read(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg) {
    uint32_t id = (bus << 24) | (dev << 19) | (func << 16) | (reg & 0xFC);
    return pcie_read(TLP_CFG_RD0, id);
}

uint32_t pcie_mem_read(uint32_t addr) {
    return pcie_read(TLP_MEM_RD, addr);
}

int main() {
	
	tx_tag = 0;
	
	wait_cycles(100000);
	
    uint32_t dev_id = pcie_cfg_read(1, 0, 0, 0x00);
    
    if (dev_id == 0xFFFFFFFF) {
        PCIE_TX_DATA = 0xBAD00000;
        while(1);
    }

	pcie_cfg_write(1, 0, 0, 0x10, 0xFFFFFFFF); 
	pcie_cfg_write(1, 0, 0, 0x14, 0xFFFFFFFF);
		
	pcie_cfg_write(1, 0, 0, 0x10, 0x00000080);  
	pcie_cfg_write(1, 0, 0, 0x14, 0x00000000); 
	
    pcie_cfg_write(1, 0, 0, 0x04, 0x06000000); 

    uint32_t test_addr = 0x80000000;
	uint32_t test_data = 0x00000006; 
	
    pcie_mem_write(test_addr, test_data);
    
    uint32_t readback = pcie_mem_read(test_addr);

    if (readback == test_data) {
        PCIE_TX_DATA = 0x0000FACE;
    } else {
        PCIE_TX_DATA = 0x0000DEAD;
    }

    while (1) {}
}