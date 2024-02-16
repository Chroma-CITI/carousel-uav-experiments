cmake_minimum_required(VERSION 3.8)
project(offboard_control)

# set(CMAKE_CXX_STANDARD 11)
# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
#   add_compile_options(-Wall -Wextra -Wpedantic)
# endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(px4_msgs REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(Boost REQUIRED filesystem)
find_package(uwb_ros_msgs REQUIRED)


# ========== TARGET ==========
add_executable(simple_control_pos src/simple_control_pos.cpp)
# Dependencies to external libraries
target_link_libraries(simple_control_pos
  Eigen3::Eigen)
# Dependencies to other ROS packages
ament_target_dependencies(simple_control_pos
  rclcpp
  px4_msgs
  Boost)

# ========== TARGET 2 ==========
add_executable(simple_control_vel src/simple_control_vel.cpp)
# Dependencies to external libraries
target_link_libraries(simple_control_vel
  Eigen3::Eigen)
# Dependencies to other ROS packages
ament_target_dependencies(simple_control_vel
  rclcpp
  px4_msgs)

# ========== TARGET 3 ==========
add_executable(uwb_formation src/uwb_formation.cpp)
# Dependencies to external libraries
target_link_libraries(uwb_formation
  Eigen3::Eigen)
# Dependencies to other ROS packages
ament_target_dependencies(uwb_formation
  rclcpp
  px4_msgs
  uwb_ros_msgs
  Boost)



if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

# Install the executables (necessary to be able to use "ros2 run")
INSTALL(
  TARGETS
  simple_control_pos
  simple_control_vel
  uwb_formation
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
