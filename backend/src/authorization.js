function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(403).json({
        success: false,
        message: 'User role not available',
      });
    }

    const userRole = String(req.user.role).trim().toLowerCase();

    const normalizedAllowedRoles = allowedRoles.map((role) =>
      String(role).trim().toLowerCase()
    );

    if (!normalizedAllowedRoles.includes(userRole)) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to access this resource',
      });
    }

    next();
  };
}

module.exports = {
  authorizeRoles,
};