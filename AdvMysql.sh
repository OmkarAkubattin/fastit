#!/bin/bash

# Install Sequelize CLI and MySQL2 driver with exact versions for stability
npm install sequelize@6 sequelize-cli@6 mysql2@2 --save-exact

# Initialize Sequelize with proper folder structure
npx sequelize init

# Create comprehensive config file with additional options
cat <<EOF > config/config.js
require('dotenv').config();

const commonConfig = {
  username: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  host: process.env.DB_HOST,
  port: process.env.DB_PORT || 3306,
  dialect: process.env.DB_DIALECT || 'mysql',
  dialectOptions: {
    bigNumberStrings: true,
    // For secure connections:
    // ssl: {
    //   ca: fs.readFileSync(__dirname + '/mysql-ca-main.crt')
    // }
  },
  pool: {
    max: 5,
    min: 0,
    acquire: 30000,
    idle: 10000
  },
  define: {
    timestamps: true,
    underscored: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    paranoid: true, // Adds deleted_at for soft deletes
    defaultScope: {
      attributes: {
        exclude: ['password'] // Always exclude password by default
      }
    }
  },
  logging: process.env.NODE_ENV === 'development' ? console.log : false,
  benchmark: true,
  timezone: '+00:00' // UTC
};

module.exports = {
  development: {
    ...commonConfig,
    logging: console.log
  },
  test: {
    ...commonConfig,
    database: process.env.TEST_DB_NAME || 'test_' + process.env.DB_NAME,
    logging: false
  },
  production: {
    ...commonConfig,
    logging: false,
    pool: {
      max: 20,
      min: 5,
      acquire: 60000,
      idle: 20000
    },
    replication: process.env.DB_READ_REPLICA_HOST ? {
      read: [
        { host: process.env.DB_READ_REPLICA_HOST },
        { host: process.env.DB_HOST }
      ],
      write: { host: process.env.DB_HOST }
    } : undefined
  }
};
EOF

# Create database connection utility
mkdir -p utils/db
cat <<EOF > utils/db/sequelize.js
const { Sequelize } = require('sequelize');
const config = require('../../config/config');

const env = process.env.NODE_ENV || 'development';
const dbConfig = config[env];

const sequelize = new Sequelize(
  dbConfig.database,
  dbConfig.username,
  dbConfig.password,
  {
    ...dbConfig,
    retry: {
      max: 3,
      match: [
        /ConnectionError/,
        /SequelizeConnectionError/,
        /SequelizeConnectionRefusedError/,
        /SequelizeHostNotFoundError/,
        /SequelizeHostNotReachableError/,
        /SequelizeInvalidConnectionError/,
        /SequelizeConnectionTimedOutError/,
        /TimeoutError/
      ],
    }
  }
);

// Test the connection
(async () => {
  try {
    await sequelize.authenticate();
    console.log('Database connection has been established successfully.');
  } catch (error) {
    console.error('Unable to connect to the database:', error);
    process.exit(1);
  }
})();

module.exports = sequelize;
EOF

# Enhanced User model with validations and hooks
cat <<EOF > models/User.js
'use strict';
const { Model } = require('sequelize');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    static associate(models) {
      User.hasMany(models.Item, { 
        foreignKey: 'user_id',
        as: 'items'
      });
    }

    // Instance method to generate JWT
    generateAuthToken() {
      return jwt.sign(
        { id: this.id, email: this.email },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRE || '1d' }
      );
    }

    // Instance method to validate password
    async validatePassword(password) {
      return await bcrypt.compare(password, this.password);
    }
  }

  User.init({
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        notNull: { msg: 'Name is required' },
        notEmpty: { msg: 'Name cannot be empty' },
        len: [2, 100]
      }
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: {
        msg: 'Email already exists'
      },
      validate: {
        isEmail: { msg: 'Please provide a valid email' },
        notNull: { msg: 'Email is required' },
        notEmpty: { msg: 'Email cannot be empty' }
      }
    },
    password: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        notNull: { msg: 'Password is required' },
        notEmpty: { msg: 'Password cannot be empty' },
        len: [6, 128]
      }
    },
    password_changed_at: DataTypes.DATE,
    password_reset_token: DataTypes.STRING,
    password_reset_expires: DataTypes.DATE,
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    },
    last_login: DataTypes.DATE
  }, {
    sequelize,
    modelName: 'User',
    tableName: 'users',
    paranoid: true,
    hooks: {
      beforeSave: async (user) => {
        if (user.changed('password')) {
          user.password = await bcrypt.hash(user.password, 12);
          user.password_changed_at = new Date();
        }
      },
      afterCreate: (user) => {
        // Remove password from output
        user.password = undefined;
      }
    },
    scopes: {
      withoutPassword: {
        attributes: { exclude: ['password'] }
      }
    }
  });

  return User;
};
EOF

# Enhanced Item model with validations
cat <<EOF > models/Item.js
'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Item extends Model {
    static associate(models) {
      Item.belongsTo(models.User, { 
        foreignKey: 'user_id',
        as: 'user'
      });
    }
  }

  Item.init({
    title: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        notNull: { msg: 'Title is required' },
        notEmpty: { msg: 'Title cannot be empty' },
        len: [3, 100]
      }
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: false,
      validate: {
        notNull: { msg: 'Description is required' },
        notEmpty: { msg: 'Description cannot be empty' },
        len: [10, 500]
      }
    },
    status: {
      type: DataTypes.ENUM('active', 'archived', 'deleted'),
      defaultValue: 'active'
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE'
    }
  }, {
    sequelize,
    modelName: 'Item',
    tableName: 'items',
    paranoid: true,
    defaultScope: {
      where: { status: 'active' }
    },
    scopes: {
      withUser: {
        include: ['user']
      },
      archived: {
        where: { status: 'archived' }
      }
    }
  });

  return Item;
};
EOF

# Create migration for Users table
cat <<EOF > migrations/$(date +%Y%m%d%H%M%S)-create-users-table.js
'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('users', {
      id: {
        allowNull: false,
        autoIncrement: true,
        primaryKey: true,
        type: Sequelize.INTEGER
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false
      },
      email: {
        type: Sequelize.STRING,
        allowNull: false,
        unique: true
      },
      password: {
        type: Sequelize.STRING,
        allowNull: false
      },
      password_changed_at: {
        type: Sequelize.DATE
      },
      password_reset_token: {
        type: Sequelize.STRING
      },
      password_reset_expires: {
        type: Sequelize.DATE
      },
      is_active: {
        type: Sequelize.BOOLEAN,
        defaultValue: true
      },
      last_login: {
        type: Sequelize.DATE
      },
      created_at: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      },
      updated_at: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
      },
      deleted_at: {
        type: Sequelize.DATE
      }
    });

    await queryInterface.addIndex('users', ['email'], {
      unique: true,
      name: 'users_email_unique'
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('users');
  }
};
EOF

# Create migration for Items table
cat <<EOF > migrations/$(date +%Y%m%d%H%M%S)-create-items-table.js
'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('items', {
      id: {
        allowNull: false,
        autoIncrement: true,
        primaryKey: true,
        type: Sequelize.INTEGER
      },
      title: {
        type: Sequelize.STRING,
        allowNull: false
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: false
      },
      status: {
        type: Sequelize.ENUM('active', 'archived', 'deleted'),
        defaultValue: 'active'
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'users',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      created_at: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      },
      updated_at: {
        allowNull: false,
        type: Sequelize.DATE,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP')
      },
      deleted_at: {
        type: Sequelize.DATE
      }
    });

    await queryInterface.addIndex('items', ['user_id'], {
      name: 'items_user_id_index'
    });

    await queryInterface.addIndex('items', ['status'], {
      name: 'items_status_index'
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('items');
  }
};
EOF

# Create seeders for initial data
cat <<EOF > seeders/$(date +%Y%m%d%H%M%S)-demo-data.js
'use strict';
const bcrypt = require('bcryptjs');

module.exports = {
  async up(queryInterface) {
    // Insert test users
    const users = await queryInterface.bulkInsert('users', [
      {
        name: 'Admin User',
        email: 'admin@example.com',
        password: await bcrypt.hash('password123', 12),
        created_at: new Date(),
        updated_at: new Date()
      },
      {
        name: 'Regular User',
        email: 'user@example.com',
        password: await bcrypt.hash('password123', 12),
        created_at: new Date(),
        updated_at: new Date()
      }
    ], { returning: true });

    // Insert test items
    await queryInterface.bulkInsert('items', [
      {
        title: 'First Item',
        description: 'This is the first test item',
        user_id: users[0].id,
        created_at: new Date(),
        updated_at: new Date()
      },
      {
        title: 'Second Item',
        description: 'This is the second test item',
        user_id: users[0].id,
        created_at: new Date(),
        updated_at: new Date()
      },
      {
        title: 'Third Item',
        description: 'This item belongs to the regular user',
        user_id: users[1].id,
        created_at: new Date(),
        updated_at: new Date()
      }
    ]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('items', null, {});
    await queryInterface.bulkDelete('users', null, {});
  }
};
EOF

echo "✅ Enhanced Sequelize setup complete with:"
echo "  - Comprehensive configuration with environment support"
echo "  - Database connection utility with error handling"
echo "  - Enhanced User model with authentication methods"
echo "  - Enhanced Item model with validations and scopes"
echo "  - Proper migrations with indexes and foreign keys"
echo "  - Demo seed data for testing"
echo "  - Soft delete (paranoid) support"
echo "  - Password hashing hooks"
echo "  - JWT token generation methods"
echo ""
echo "Next steps:"
echo "1. Update your .env file with database credentials"
echo "2. Run migrations: npx sequelize-cli db:migrate"
echo "3. Seed demo data: npx sequelize-cli db:seed:all"
