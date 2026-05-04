import { prisma } from "../../db";
import type { BillCreateRequest } from "./model";

export class BillService {
    static async createBill(userid: string, data: BillCreateRequest) {
        try {
            const bill = await prisma.bills.create({
                data: {
                    created_by: userid,
                    name: data.name,
                    date: data.date,
                    vat_pct: data.vat_pct,
                    status: "Active",
                    service_charge_pct: 0,
                    invite_code: Math.random().toString(36).substring(2, 8).toUpperCase(),
                    bill_members: {
                        create: {
                            user_id: userid,   
                            role: "Owner",
                        }
                    }
                },
            });
            return bill;
        } catch (error: any) {            throw error;
        }
    }
}



