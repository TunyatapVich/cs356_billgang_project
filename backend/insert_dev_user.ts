import { prisma } from "./src/db";

const email = "admin";
const password = "123";

const hash = await Bun.password.hash(password);
console.log("Hash:", hash);

const user = await prisma.users.create({
  data: {
    email,
    password_hash: hash,
  },
});

console.log("Created:", user.id, user.email);
await prisma.$disconnect();