# Install Sequelize CLI and MySQL2 driver (if not already done)
npm install sequelize mysql2

# Initialize Sequelize (will create config, models, migrations folders)
npx sequelize init

# Create config/config.js
cat <<EOF > config/config.js
require('dotenv').config();

module.exports = {
  development: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    dialect: process.env.DB_DIALECT
  },
  test: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    dialect: process.env.DB_DIALECT
  },
  production: {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: process.env.DB_HOST,
    dialect: process.env.DB_DIALECT
  }
};
EOF

echo "✅ Sequelize config/config.js file created"

# Overwrite or create models/User.js
cat <<EOF > models/User.js
'use strict';
const { Model } = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class User extends Model {
    static associate(models) {
      User.hasMany(models.Item, { foreignKey: 'userId' });
    }
  }
  User.init({
    name: DataTypes.STRING,
    email: { type: DataTypes.STRING, unique: true },
    password: DataTypes.STRING
  }, {
    sequelize,
    modelName: 'User',
    timestamps: true,
  });
  return User;
};
EOF

# Create models/Item.js
cat <<EOF > models/Item.js
'use strict';
const { Model } = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class Item extends Model {
    static associate(models) {
      Item.belongsTo(models.User, { foreignKey: 'userId' });
    }
  }
  Item.init({
    title: DataTypes.STRING,
    description: DataTypes.STRING,
    userId: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Users',
        key: 'id'
      }
    }
  }, {
    sequelize,
    modelName: 'Item',
    timestamps: true,
  });
  return Item;
};
EOF

echo "✅ Sequelize MySQL models created: User.js and Item.js"
