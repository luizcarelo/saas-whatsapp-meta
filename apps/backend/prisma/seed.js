const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

const tenantName = process.env.SEED_TENANT_NAME || 'LH Solucao';
const tenantDocument = process.env.SEED_TENANT_DOCUMENT || null;
const adminName = process.env.SEED_ADMIN_NAME || 'Administrador';
const adminEmail = process.env.SEED_ADMIN_EMAIL || 'admin@lhsolucao.com.br';
const adminPassword = process.env.SEED_ADMIN_PASSWORD || '';

const permissions = [
  ['tenants.read', 'tenants'],
  ['tenants.update', 'tenants'],
  ['users.read', 'users'],
  ['users.create', 'users'],
  ['users.update', 'users'],
  ['users.delete', 'users'],
  ['roles.read', 'roles'],
  ['roles.create', 'roles'],
  ['roles.update', 'roles'],
  ['permissions.read', 'permissions'],
  ['contacts.read', 'contacts'],
  ['contacts.create', 'contacts'],
  ['contacts.update', 'contacts'],
  ['contacts.delete', 'contacts'],
  ['conversations.read', 'conversations'],
  ['conversations.reply', 'conversations'],
  ['conversations.assign', 'conversations'],
  ['conversations.close', 'conversations'],
  ['messages.read', 'messages'],
  ['messages.send', 'messages'],
  ['whatsapp_accounts.read', 'whatsapp_accounts'],
  ['whatsapp_accounts.create', 'whatsapp_accounts'],
  ['whatsapp_accounts.update', 'whatsapp_accounts'],
  ['whatsapp_accounts.delete', 'whatsapp_accounts'],
  ['chatbot.read', 'chatbot'],
  ['chatbot.create', 'chatbot'],
  ['chatbot.update', 'chatbot'],
  ['settings.read', 'settings'],
  ['settings.update', 'settings'],
  ['reports.view', 'reports'],
  ['audit_logs.read', 'audit_logs'],
  ['billing.view', 'billing']
];

const rolePermissions = {
  owner: permissions.map((item) => item[0]),
  admin: permissions.map((item) => item[0]).filter((key) => key !== 'billing.view'),
  manager: [
    'contacts.read',
    'contacts.create',
    'contacts.update',
    'conversations.read',
    'conversations.reply',
    'conversations.assign',
    'conversations.close',
    'messages.read',
    'messages.send',
    'chatbot.read',
    'reports.view'
  ],
  agent: [
    'contacts.read',
    'contacts.update',
    'conversations.read',
    'conversations.reply',
    'messages.read',
    'messages.send'
  ],
  viewer: [
    'contacts.read',
    'conversations.read',
    'messages.read',
    'reports.view'
  ]
};

async function main() {
  if (!adminPassword || adminPassword.length < 8) {
    throw new Error('SEED_ADMIN_PASSWORD ausente ou insegura');
  }

  const tenant = await prisma.tenant.upsert({
    where: {
      id: '00000000-0000-0000-0000-000000000001'
    },
    update: {
      name: tenantName,
      document: tenantDocument,
      status: 'active'
    },
    create: {
      id: '00000000-0000-0000-0000-000000000001',
      name: tenantName,
      document: tenantDocument,
      status: 'active'
    }
  });

  for (const item of permissions) {
    const key = item[0];
    const moduleName = item[1];

    await prisma.permission.upsert({
      where: {
        key
      },
      update: {
        module: moduleName
      },
      create: {
        key,
        module: moduleName,
        description: key
      }
    });
  }

  const createdRoles = {};

  for (const roleName of Object.keys(rolePermissions)) {
    const role = await prisma.role.upsert({
      where: {
        tenantId_name: {
          tenantId: tenant.id,
          name: roleName
        }
      },
      update: {
        isSystem: true
      },
      create: {
        tenantId: tenant.id,
        name: roleName,
        description: roleName,
        isSystem: true
      }
    });

    createdRoles[roleName] = role;

    for (const permissionKey of rolePermissions[roleName]) {
      const permission = await prisma.permission.findUnique({
        where: {
          key: permissionKey
        }
      });

      if (permission) {
        await prisma.rolePermission.upsert({
          where: {
            roleId_permissionId: {
              roleId: role.id,
              permissionId: permission.id
            }
          },
          update: {},
          create: {
            roleId: role.id,
            permissionId: permission.id
          }
        });
      }
    }
  }

  const passwordHash = await bcrypt.hash(adminPassword, 12);

  const admin = await prisma.user.upsert({
    where: {
      tenantId_email: {
        tenantId: tenant.id,
        email: adminEmail
      }
    },
    update: {
      name: adminName,
      passwordHash,
      status: 'active'
    },
    create: {
      tenantId: tenant.id,
      name: adminName,
      email: adminEmail,
      passwordHash,
      status: 'active'
    }
  });

  await prisma.userRole.upsert({
    where: {
      userId_roleId: {
        userId: admin.id,
        roleId: createdRoles.owner.id
      }
    },
    update: {},
    create: {
      tenantId: tenant.id,
      userId: admin.id,
      roleId: createdRoles.owner.id
    }
  });

  await prisma.auditLog.create({
    data: {
      tenantId: tenant.id,
      userId: admin.id,
      action: 'seed_initial_data',
      entity: 'system',
      metadata: {
        tenantName,
        adminEmail
      }
    }
  });

  const result = {
    tenantId: tenant.id,
    tenantName: tenant.name,
    adminId: admin.id,
    adminEmail: admin.email,
    roles: Object.keys(createdRoles).length,
    permissions: permissions.length
  };

  console.log(JSON.stringify(result, null, 2));
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
